#!/usr/bin/env bash
# Clone (or update) every source repo into src/, pin SHAs in repos.lock, apply our patches.
# With an existing repos.lock the pinned SHAs are checked out; pass --update to move to latest.
set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM="fishui cutefish-framework qt-plugins filemanager shell core settings kwin-plugins
terminal icons wallpapers sddm-theme screenshot calculator gtk-themes cursor-themes plymouth-theme"
LEGACY="cutefish-calamares-settings"   # only in the old cutefishos-ubuntu forks
ARCHIVED="texteditor"                 # original source, archived in the cutefishs org

repos=()
for r in $UPSTREAM; do repos+=("$r https://github.com/cutefishos/$r.git"); done
for r in $LEGACY;   do repos+=("$r https://github.com/cutefishos-ubuntu/$r.git"); done
for r in $ARCHIVED; do repos+=("$r https://github.com/cutefishs/$r.git"); done

declare -A pinned=()
if [[ -f repos.lock && "${1:-}" != "--update" ]]; then
    while read -r name _url sha; do pinned[$name]=$sha; done < <(grep -v '^#' repos.lock)
fi

echo "# name url sha" > repos.lock.new
for entry in "${repos[@]}"; do
    read -r name url <<<"$entry"
    dir="src/$name"
    [[ -d $dir/.git ]] || git clone -q "$url" "$dir"
    git -C "$dir" fetch -q origin
    sha=$(git -C "$dir" rev-parse "${pinned[$name]:-origin/HEAD}")
    git -C "$dir" checkout -q -B remastered "$sha"
    printf 'obj-*/
debian/.debhelper/
debian/files
debian/*.substvars
debian/*.debhelper.log
debian/*.debhelper
debian/debhelper-build-stamp
debian/*/
!debian/source/
!debian/patches/
!debian/tests/
' > "$dir/.git/info/exclude"
    if compgen -G "patches/$name/*.patch" >/dev/null; then
        git -C "$dir" -c user.name=remastered -c user.email=remastered@localhost \
            am -q --3way "$PWD"/patches/"$name"/*.patch
    fi
    echo "$name $url $sha" >> repos.lock.new
    echo "ok  $name"
done
mv repos.lock.new repos.lock

# KWin: Ubuntu's 26.04 source + our per-output virtual desktop backport (patches/kwin).
KWIN_VERSION=4:6.6.6-0ubuntu0.1
if [[ ! -d src/kwin-ubuntu/debian ]]; then
    mkdir -p build/kwin-src
    docker run --rm -v "$PWD/build/kwin-src":/out cutefish-builder bash -c "
        cd /out && rm -rf kwin kwin_* && apt-get update -qq && apt-get source -qq --download-only kwin=$KWIN_VERSION &&
        dpkg-source -x kwin_*.dsc kwin && chown -R $(id -u):$(id -g) /out"
    cp -a build/kwin-src/kwin src/kwin-ubuntu
    (cd src/kwin-ubuntu
     git init -q && git add -A && git -c user.name=r -c user.email=r@l commit -qm "ubuntu kwin $KWIN_VERSION"
     git -c user.name=r -c user.email=r@l am -q ../../patches/kwin/*.patch
     for p in ../../patches/kwin/*.patch; do
         cp "$p" debian/patches/; n=$(basename "$p")
         echo "$n" >> debian/patches/series; echo "$n" >> .pc/applied-patches
     done
     { echo "kwin (4:6.6.6-0ubuntu0.1+cutefish2) resolute; urgency=medium"; echo
       echo "  * Backport per-output virtual desktops (KWin MR !8602, Plasma 6.7)."
       echo "  * blur: ForceBlurClasses option for per-app blur, at full blur strength."; echo
       echo " -- Cutefish Remastered <remastered@localhost>  $(date -R)"; echo
       cat debian/changelog; } > debian/changelog.new && mv debian/changelog.new debian/changelog
     git add -A && git -c user.name=r -c user.email=r@l commit -qm "debian: register cutefish patches")
    echo "ok  kwin-ubuntu"
fi

# Calamares: Ubuntu's 26.04 source + our patches (patches/calamares), so the
# installer's time zone no longer picks the language or the formats.
CALAMARES_VERSION=3.3.14-0ubuntu25
if [[ ! -d src/calamares-ubuntu/debian ]]; then
    mkdir -p build/calamares-src
    (cd build/calamares-src && rm -rf calamares calamares_*
     # The archive pool drops a version once it's superseded; Launchpad keeps
     # every one. dpkg-source checks the files against the .dsc.
     pool=http://archive.ubuntu.com/ubuntu/pool/universe/c/calamares
     lp=https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/calamares/$CALAMARES_VERSION
     for f in calamares_$CALAMARES_VERSION.dsc calamares_${CALAMARES_VERSION%-*}.orig.tar.gz \
              calamares_$CALAMARES_VERSION.debian.tar.xz; do
         curl -fsSLO "$pool/$f" || curl -fsSLO "$lp/$f"
     done
     dpkg-source -x calamares_$CALAMARES_VERSION.dsc calamares >/dev/null)
    cp -a build/calamares-src/calamares src/calamares-ubuntu
    (cd src/calamares-ubuntu
     git init -q && git add -A && git -c user.name=r -c user.email=r@l commit -qm "ubuntu calamares $CALAMARES_VERSION"
     git -c user.name=r -c user.email=r@l am -q ../../patches/calamares/*.patch
     # Use the system Python: Modal's image puts its own Python 3.12 first in
     # PATH, and linking that next to Ubuntu's boost_python (3.14) fails
     # (setback 34). Skip building the tests, which Ubuntu doesn't run either.
     sed -i 's|-DBoost_PYTHON_VERSION=3.14$|& -DBUILD_TESTING=OFF -DPython_EXECUTABLE=/usr/bin/python3|' debian/rules
     for p in ../../patches/calamares/*.patch; do
         cp "$p" debian/patches/; n=$(basename "$p")
         echo "$n" >> debian/patches/series; echo "$n" >> .pc/applied-patches
     done
     { echo "calamares ($CALAMARES_VERSION+cutefish1) resolute; urgency=medium"; echo
       echo "  * locale: the time zone no longer picks the language or the formats;"
       echo "    both follow the selected language until changed on the page."; echo
       echo " -- Cutefish Remastered <remastered@localhost>  $(date -R)"; echo
       cat debian/changelog; } > debian/changelog.new && mv debian/changelog.new debian/changelog
     git add -A && git -c user.name=r -c user.email=r@l commit -qm "debian: register cutefish patches")
    echo "ok  calamares-ubuntu"
fi
