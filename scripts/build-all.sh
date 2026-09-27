#!/usr/bin/env bash
# Build the packages, the ISO, and boot it in the VM, in one go.
#
#   scripts/build-all.sh [--skip STEPS] [--modal] [--pkgs "settings core"] [--vm-install]
#
# Steps (all run by default, in this order):
#   build  compile and package our apps into .debs in build/repo. Locally in
#          Docker (scripts/build-debs.sh), or on Modal with --modal.
#          Packages: --pkgs, or every app in iso-packages.yml.
#   iso    build/cutefish-os-26.04-amd64.iso (scripts/build-iso.sh, Docker).
#   vm     boot the new ISO in the cutefish-efi VM (live session) and screenshot it.
#          --vm-install also installs it to a NEW EMPTY disk with Calamares (the VM's
#          old disk is deleted), then boots and logs in to the installed system.
# --skip takes a comma list in any order: --skip build  or  --skip build,vm.
#   (build_apps, deb_packages, make_iso and install_vm are accepted as aliases.)
#
# iso-packages.yml decides which apps are in the ISO: this script writes its
# lists into cutefish-desktop's Depends (packaging/debian/control) and
# rebuilds the meta package when they change.
#
# All output scrolls above a progress bar and is saved to
# build/logs/build-all-<time>.log. Docker Desktop and a running VM can't share
# VT-x, so each step stops the one it doesn't need.
set -uo pipefail
shopt -s lastpipe
cd "$(dirname "$0")/.."

usage() { sed -n '2,/^set /{/^set /d;s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

skip=" " modal="" pkgs="" vm_install=""
while (( $# )); do
    case $1 in
        --skip)
            list=${2:?--skip needs a list}; shift
            while [[ $list == *, && $# -gt 1 ]]; do list+=$2; shift; done   # "--skip build, vm"
            for s in ${list//,/ }; do
                case $s in
                    build|build_apps|deb_packages) skip+="build " ;;
                    iso|make_iso)                  skip+="iso " ;;
                    vm|install_vm)                 skip+="vm " ;;
                    *) echo "unknown step '$s' (build, iso, vm)" >&2; exit 2 ;;
                esac
            done ;;
        --modal)      modal=1 ;;
        --pkgs)       pkgs=${2:?--pkgs needs a list}; shift ;;
        --vm-install) vm_install=1 ;;
        -h|--help)    usage ;;
        *) echo "unknown option $1" >&2; usage 2 ;;
    esac
    shift
done
skipped() { [[ $skip == *" $1 "* ]]; }

VM=cutefish-efi
YML=iso-packages.yml
CONTROL=packaging/debian/control
mkdir -p build/logs
LOG=$PWD/build/logs/build-all-$(date +%Y%m%d-%H%M%S).log

# ---- progress bar -----------------------------------------------------------
# The last terminal line is kept out of the scroll region (tput csr) and holds
# the bar; everything else scrolls above it.
TTY=""; [[ -t 1 ]] && tput lines >/dev/null 2>&1 && TTY=1   # no bar without a usable terminal
steps=()
for s in build iso vm; do skipped $s || steps+=("$s"); done
declare -A weight=([build]=45 [iso]=40 [vm]=15)
[[ -n $vm_install ]] && weight[vm]=30
total=0; for s in "${steps[@]}"; do (( total += weight[$s] )); done
done_w=0 step="" step_no=0 units=1 unit=0 what="" status=""

ui_init() {
    [[ -n $TTY ]] || return 0
    rows=$(tput lines) cols=$(tput cols)
    printf '\n'; tput csr 0 $(( rows - 2 )); tput cup $(( rows - 2 )) 0
}
ui_end() {
    [[ -n $TTY ]] || return 0
    rows=$(tput lines)
    tput csr 0 $(( rows - 1 )); tput cup $(( rows - 1 )) 0; printf '\n'
}
trap ui_end EXIT
trap 'rows=$(tput lines) cols=$(tput cols); tput csr 0 $(( rows - 2 )); draw' WINCH
trap 'status=interrupted; draw; exit 130' INT TERM

draw() {
    [[ -n $TTY ]] || return 0
    local pct=0 w=0 t
    [[ -n $step ]] && w=${weight[$step]}
    (( total > 0 )) && pct=$(( (done_w * 100 + w * 100 * unit / units) / total ))
    (( pct > 100 )) && pct=100
    t=$(printf '%02d:%02d:%02d' $(( SECONDS / 3600 )) $(( SECONDS / 60 % 60 )) $(( SECONDS % 60 )))
    local info=" $pct%  $step_no/${#steps[@]} $step: ${status:-$what}  $t"
    local barw=$(( cols - ${#info} - 2 )); (( barw > 40 )) && barw=40; (( barw < 5 )) && barw=5
    local fill=$(( barw * pct / 100 )) bar
    printf -v bar '%*s' "$fill" ''; bar=${bar// /#}
    printf -v t '%*s' $(( barw - fill )) ''; bar+=${t// /-}
    local color=7; [[ $status == FAILED* || $status == interrupted ]] && color=1; [[ $status == done ]] && color=2
    tput sc; tput cup $(( rows - 1 )) 0; tput el
    printf '%s[%s]%s%s' "$(tput setaf $color)" "$bar" "${info:0:$(( cols - barw - 3 ))}" "$(tput sgr0)"
    tput rc
}

# say TEXT: a log line of our own.
say() { printf '%s\n' "$*" >> "$LOG"; printf '\033[1m%s\033[0m\n' "$*"; draw; }

# run MARKER CMD...: run CMD, show and log its output; each line matching the
# regex MARKER is one unit of progress, and its first group becomes the label.
run() {
    local marker=$1 line buf="" rc; shift
    "$@" 2>&1 < /dev/null | while :; do
        if IFS= read -r -t 1 line; then
            line=$buf$line buf=""
            printf '%s\n' "$line" >> "$LOG"; printf '%s\n' "$line"
            if [[ $line =~ $marker ]]; then
                (( unit < units )) && (( unit++ ))
                what=${BASH_REMATCH[1]:-$line}
            fi
        else
            rc=$? buf+=$line
            if (( rc <= 128 )); then   # end of output (> 128 is the 1 s timeout: redraw the clock)
                [[ -n $buf ]] && { printf '%s\n' "$buf" >> "$LOG"; printf '%s\n' "$buf"; }
                break
            fi
        fi
        draw
    done
    return "${PIPESTATUS[0]}"
}

begin() { step=$1 units=$2 unit=0 what="starting"; (( step_no++ )); say ">>>> step $step_no/${#steps[@]}: $1"; }
finish() { (( done_w += weight[$step] )); unit=0; }
fail() { status="FAILED: $1 (log: ${LOG#"$PWD"/})"; say "FAILED: $1"; say "log: $LOG"; draw; exit 1; }

# ---- host: Docker Desktop vs VirtualBox ------------------------------------
stop_vms() {
    local vm
    VBoxManage list runningvms 2>/dev/null | sed -n 's/^"\(cutefish-[^"]*\)".*/\1/p' | while read -r vm; do
        say "powering off $vm (Docker needs VT-x)"; VBoxManage controlvm "$vm" poweroff >/dev/null 2>&1
    done
    sleep 2
}
start_docker() {
    docker info >/dev/null 2>&1 && return 0
    stop_vms
    say "starting Docker Desktop"
    systemctl --user start docker-desktop || return 1
    local deadline=$(( SECONDS + 240 ))
    until docker info >/dev/null 2>&1; do (( SECONDS < deadline )) || return 1; sleep 3; draw; done
    docker image inspect cutefish-builder >/dev/null 2>&1 || { say "no cutefish-builder image: see docs/building.md"; return 1; }
}
stop_docker() {
    systemctl --user is-active -q docker-desktop 2>/dev/null || return 0
    say "stopping Docker Desktop (VirtualBox needs VT-x)"
    systemctl --user stop docker-desktop
}

# ---- iso-packages.yml -------------------------------------------------------
# yml_apps: "key<TAB>value" per app; yml_extra: one package per line.
yml_apps() {
    awk '/^[^ #]/ {sec=$1} sec=="apps:" && /^  [^ #-]/ {
        sub(/#.*/, ""); k=$1; sub(/:$/, "", k); $1=""; sub(/^ +/, ""); sub(/ +$/, ""); print k "\t" $0 }' "$YML"
}
yml_extra() { awk '/^[^ #]/ {sec=$1} sec=="extra:" && /^  - / {sub(/#.*/, ""); print $2}' "$YML"; }
# The Depends lines between the markers in packaging/debian/control.
meta_block() {
    echo "# Our apps"
    yml_apps | cut -f2 | grep . | tr ',' '\n' | sed 's/^ *//; s/ *$//; s/^/         /; s/$/,/'
    echo "# Everyday apps (Firefox from Mozilla's APT repository, no snap)"
    yml_extra | sed 's/^/         /; s/$/,/'
}
current_block() { sed -n '/^# BEGIN iso-packages.yml/,/^# END iso-packages.yml/p' "$CONTROL" | sed '1d;$d'; }
write_block() {
    local new; new=$(meta_block)
    awk -v block="$new" '/^# BEGIN iso-packages.yml/ {print; print block; skip=1; next}
        /^# END iso-packages.yml/ {skip=0} !skip' "$CONTROL" > "$CONTROL.new" && mv "$CONTROL.new" "$CONTROL"
    local head v
    head=$(head -1 packaging/debian/changelog)
    v=$(sed -n 's/^cutefish-meta (\(.*\)) .*/\1/p' <<<"$head")
    v=${v%.*}.$(( ${v##*.} + 1 ))
    { printf 'cutefish-meta (%s) resolute; urgency=medium\n\n' "$v"
      printf '  * cutefish-desktop: app list regenerated from iso-packages.yml.\n\n'
      printf ' -- Cutefish Remastered <remastered@localhost>  %s\n\n' "$(date -R)"
      cat packaging/debian/changelog; } > packaging/debian/changelog.new
    mv packaging/debian/changelog.new packaging/debian/changelog
    say "iso-packages.yml changed: cutefish-desktop Depends rewritten, meta is now $v"
}

# ---- steps ------------------------------------------------------------------
step_build() {
    local list=$pkgs
    [[ -n $list ]] || list="$(yml_apps | cut -f1 | tr '\n' ' ') meta"
    if [[ "$(meta_block)" != "$(current_block)" ]]; then
        write_block
        [[ " $list " == *" meta "* ]] || list+=" meta"
    fi
    local n; n=$(wc -w <<<"$list")
    begin build "$n"
    say "packages: $list"
    if [[ -n $modal ]]; then
        say "building on Modal (profile mhabrarmts2); don't edit src/ while it uploads"
        run '^>>> (.+)' env MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run --detach scripts/modal_build.py --pkgs "$list" \
            || fail "Modal build (per-package logs in build/logs/)"
    else
        start_docker || fail "Docker Desktop didn't start"
        run '^>>> (.+)' scripts/build-debs.sh $list || fail "local build (per-package logs in build/logs/)"
    fi
    local p missing=""
    for p in $(yml_apps | cut -f2 | tr ',' '\n' | sed 's/(.*//') $(yml_extra | grep '^cutefish'); do
        grep -qx "Package: $p" build/repo/Packages || missing+=" $p"
    done
    [[ -z $missing ]] || fail "no deb in build/repo for:$missing"
    finish
}

step_iso() {
    begin iso 6   # the six ">>> …" phases of build-iso.sh
    if skipped build && [[ "$(meta_block)" != "$(current_block)" ]]; then
        fail "iso-packages.yml changed but the meta package wasn't rebuilt: run without --skip build"
    fi
    start_docker || fail "Docker Desktop didn't start"
    run '^>>> (.+)' scripts/build-iso.sh || fail "ISO build (see build/logs/iso-*.log)"
    finish
}

# vm_do LABEL CMD...: one VM sub-step (progress comes from vm_next, so no marker matches).
vm_do() { what=$1; shift; say ">>> $what"; run '^$never' "$@"; }
vm_next() { (( unit++ )); draw; }

step_vm() {
    local vm=scripts/vm.sh
    begin vm "$([[ -n $vm_install ]] && echo 11 || echo 5)"
    [[ -f build/cutefish-os-26.04-amd64.iso ]] || fail "no ISO to boot"
    stop_docker
    VBoxManage showvminfo "$VM" >/dev/null 2>&1 || { vm_do "creating $VM" $vm create efi || fail "vm create"; }
    VBoxManage controlvm "$VM" poweroff >/dev/null 2>&1 && sleep 3
    vm_next
    if [[ -n $vm_install ]]; then
        vm_do "new empty disk" $vm disk efi fresh || fail "vm disk"
    else
        vm_do "live boot: detaching the disk" $vm disk efi detach || fail "vm disk"
    fi
    vm_do "inserting the ISO" $vm dvd efi iso || fail "vm dvd"; vm_next
    vm_do "booting" $vm start efi || fail "vm start"; vm_next
    vm_do "waiting for the live desktop" $vm wait-desktop efi 600 || fail "live desktop didn't come up"; vm_next
    sleep 5
    vm_do "screenshot" $vm shot efi build-all-live || fail "screenshot"; vm_next
    [[ -n $vm_install ]] || { finish; return; }

    vm_do "installing with Calamares (keyboard)" $vm calamares efi 0 || fail "calamares"; vm_next
    vm_do "waiting for the install" $vm wait-install efi || fail "the install failed"; vm_next
    VBoxManage controlvm "$VM" poweroff >/dev/null 2>&1; sleep 3
    vm_do "ejecting the ISO" $vm dvd efi empty || fail "vm dvd"; vm_next
    vm_do "booting the installed system" $vm start efi || fail "vm start"; vm_next
    what="waiting for the login screen"; say ">>> $what"
    local deadline=$(( SECONDS + 600 ))
    until VM_USER=testu VM_PASS=cutefish123 $vm run efi /usr/bin/pgrep -x sddm-greeter-qt >/dev/null 2>&1; do
        (( SECONDS < deadline )) || fail "no login screen"; sleep 5; draw
    done
    sleep 5
    VBoxManage controlvm "$VM" keyboardputstring cutefish123; VBoxManage controlvm "$VM" keyboardputscancode 1c 9c
    VM_USER=testu VM_PASS=cutefish123 vm_do "logging in as testu" $vm wait-desktop efi 180 || fail "no desktop after login"
    vm_next; sleep 5
    vm_do "screenshot" $vm shot efi build-all-installed || fail "screenshot"
    finish
}

(( ${#steps[@]} )) || { echo "every step skipped" >&2; exit 2; }
ui_init
say "build-all: ${steps[*]}${modal:+ (Modal)}${vm_install:+ (+ disk install)}; log: $LOG"
for s in "${steps[@]}"; do "step_$s"; done
step="" status=done unit=0; done_w=$total
say "all done in $(( SECONDS / 60 )) min"
