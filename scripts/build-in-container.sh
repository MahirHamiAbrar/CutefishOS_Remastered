#!/usr/bin/env bash
# Builds Cutefish packages inside an Ubuntu 26.04 builder (Docker or Modal).
# Usage: build-in-container.sh <package> ...
# Env: WS    workspace with src/, netmonitor/, packaging/ (read only)
#      BUILD scratch dir for build trees (kept between runs: RESUME=1)
#      OUT   where repo/ (debs + Packages) and logs/ are written
#      JOBS, RESUME as in build-debs.sh
: "${WS:=/ws}" "${BUILD:=/build}" "${OUT:=/ws/build}"
mkdir -p "$OUT/repo" "$OUT/logs"
set -euo pipefail
# KWin last: it takes hours in a small VM and only kwin-plugins needs it.
ORDER="fishui cutefish-framework qt-plugins filemanager shell core settings terminal icons
wallpapers sddm-theme screenshot calculator texteditor gtk-themes cursor-themes plymouth-theme
netmonitor meta kwin kwin-plugins calamares"
[[ $# -gt 0 ]] || set -- $ORDER

mem_gb=$(awk '/MemTotal/ {print int($2 / 1024 / 1024)}' /proc/meminfo)
jobs=${JOBS:-$(( mem_gb * 2 / 3 > 0 ? mem_gb * 2 / 3 : 1 ))}
(( jobs > $(nproc) )) && jobs=$(nproc)
echo "building with -j$jobs (${mem_gb} GB RAM in the container)"
# LTO roughly doubles compile memory and makes KWin's link take GBs: not worth
# it in a 4 GB Docker Desktop VM.
export DEB_BUILD_MAINT_OPTIONS="optimize=-lto"

index() { (cd $OUT/repo && dpkg-scanpackages -m . > Packages 2>/dev/null); }
index
echo "deb [trusted=yes] copy:$OUT/repo ./" > /etc/apt/sources.list.d/local.list
apt-get update -qq 2>/dev/null

# Every file in our debs used to come out dated 2022-01-01: Modal's image
# sets SOURCE_DATE_EPOCH to that, dpkg-buildpackage keeps a preset value, and
# dpkg-deb clamps every mtime to it. Qt keeps using its QML disk cache for QML
# compiled into a binary as long as the binary's mtime is unchanged, so an
# upgraded app went on running its old QML (setback 32). Unset it, so that
# dpkg-buildpackage takes each package's changelog date, and stamp the files
# with that date right before dpkg-deb packs them: every new version gets new
# mtimes.
echo "builder SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-unset} (unset for the build)"
unset SOURCE_DATE_EPOCH
# The builder image may carry tools of its own in /usr/local/bin: Modal's has
# Python 3.12 there, first in PATH, which broke every build step started with
# "env python3" (dh_qmldeps) and linked Calamares against the wrong libpython
# (setback 34). Builds see only the system's tools, plus our dpkg-deb wrapper.
mkdir -p /opt/cutefish-build/bin
export PATH=/opt/cutefish-build/bin:/usr/sbin:/usr/bin:/sbin:/bin
cat > /opt/cutefish-build/bin/dpkg-deb <<'EOF'
#!/bin/sh
if [ -n "$SOURCE_DATE_EPOCH" ]; then
    for arg in "$@"; do
        [ -d "$arg/DEBIAN" ] && find "$arg" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
    done
fi
exec /usr/bin/dpkg-deb "$@"
EOF
chmod +x /opt/cutefish-build/bin/dpkg-deb

# Copy a source tree into the volume, keeping its build tree (obj-*).
sync_tree() {
    local from=$1 to=$2
    mkdir -p "$to"
    find "$to" -mindepth 1 -maxdepth 1 ! -name 'obj-*' -exec rm -rf {} +
    # cp rather than a tar pipe: GNU tar fails with ENOSYS under gVisor (Modal).
    cp -a "$from"/. "$to"/
    rm -rf "${to:?}/.git" "${to:?}/debian/.debhelper"
}

# Settings, Files and Terminal build the framework's applications library
# from ../cutefish-framework, so it must sit next to them in the volume.
sync_tree $WS/src/cutefish-framework $BUILD/src/cutefish-framework

# Files a package must ship. A component skipped at configure time (a QUIET
# find_package, say) still gives a package that installs fine (setback 33).
declare -A must=(
    [kwin-plugins]="/cutefish_roundedwindow.so|/cutefish_blur.so|/org.cutefish.decoration.so"
    [calamares]="/usr/bin/calamares$"
)

# has_files "a|b" debs…: every |-separated pattern matches a file in the debs.
has_files() {
    local list pat; list=$(for d in "${@:2}"; do dpkg -c "$d"; done)
    IFS='|' read -ra pats <<<"$1"
    for pat in "${pats[@]}"; do
        grep -q -- "$pat" <<<"$list" || { echo "no $pat in the debs"; return 1; }
    done
}

fail=()
for p in "$@"; do
    case $p in
        kwin)       from=$WS/src/kwin-ubuntu ;;
        calamares)  from=$WS/src/calamares-ubuntu ;;
        netmonitor) from=$WS/netmonitor ;;
        meta)       from=$WS/packaging ;;
        *)          from=$WS/src/$p ;;
    esac
    [[ -d $from/debian ]] || { echo "skip $p (no debian/)"; continue; }
    dir=$BUILD/src/$(basename "$from")
    log=$OUT/logs/$p.log
    echo ">>> $p"
    sync_tree "$from" "$dir"
    rm -f $BUILD/src/*.deb $BUILD/src/*.ddeb $BUILD/src/*.buildinfo $BUILD/src/*.changes
    # Chained with && on purpose: set -e does not apply inside an if condition.
    if ( cd "$dir" &&
         mk-build-deps -i -r -t "apt-get -y -q --no-install-recommends" debian/control &&
         rm -f ./*-build-deps_* &&
         dpkg-buildpackage -b -us -uc -j"$jobs" ${RESUME:+-nc} &&
         { [[ -z ${must[$p]:-} ]] || has_files "${must[$p]}" ../*.deb; } &&
         cp ../*.deb $OUT/repo/
       ) > "$log" 2>&1; then
        echo "    ok: $(cd $BUILD/src && ls *.deb | tr '\n' ' ')"
    else
        echo "    FAILED (see build/logs/$p.log)"; tail -15 "$log"; fail+=("$p")
    fi
    index; apt-get update -qq 2>/dev/null
done
[[ -n ${HOST_UID:-} ]] && chown -R "$HOST_UID:$HOST_GID" "$OUT/repo" "$OUT/logs"
[[ ${#fail[@]} -eq 0 ]] || { echo "failed: ${fail[*]}"; exit 1; }
