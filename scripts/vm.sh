#!/usr/bin/env bash
# VirtualBox test harness for the Cutefish ISO. VM disks live in build/vm/
# (VirtualBox's own registry in ~/.config/VirtualBox is the only file written
# outside the workspace).
#
#   scripts/vm.sh create [efi|bios]   create VM "cutefish-<fw>" (2 displays, 3D, NAT,
#                                     USB mass-storage sticks with NTFS and exFAT)
#   scripts/vm.sh start  [efi|bios]   boot it headless (watch with the VirtualBox GUI or shots)
#   scripts/vm.sh shot   [efi|bios] NAME   save screenshots of both displays to build/vm/shots/
#   scripts/vm.sh type   [efi|bios] TEXT   type TEXT into the VM
#   scripts/vm.sh run    [efi|bios] CMD... run a command in the guest as the live user (guest additions)
#   scripts/vm.sh srun   [efi|bios] SHELL-CMD  same, but inside the graphical session (polkit sees an
#                                     active session, so udisks/NetworkManager actions are allowed)
#   scripts/vm.sh displays [efi|bios] N [WxH]  turn on N displays side by side (default 2, 1280x800)
#   scripts/vm.sh stop   [efi|bios]
#   scripts/vm.sh destroy [efi|bios]
#
# Boot media:
#   scripts/vm.sh dvd    [efi|bios] iso|empty      put build/…iso in the DVD drive, or eject it
#   scripts/vm.sh disk   [efi|bios] detach|attach [PATH]|fresh
#                                     detach the system disk (its path is kept in
#                                     build/vm/<vm>/disk.path), attach it again, or replace
#                                     it with a new empty disk (the old one is DELETED)
# In a running session:
#   scripts/vm.sh wait-desktop [efi|bios] [SECONDS]  wait until cutefish-shell runs (default 600 s)
#   scripts/vm.sh install-debs [efi|bios] DEB...     dpkg -i the debs, restart the session
#   scripts/vm.sh app    [efi|bios] ID [ARG...]      start an app inside the session (AppRuntime)
#   scripts/vm.sh mouse  [efi|bios]           ydotool as the agent's mouse (live session: installs it)
#   scripts/vm.sh click  [efi|bios] X Y       left-click at X,Y (display-0 pixels); needs "mouse"
#   scripts/vm.sh cursor [efi|bios]           print KWin's cursor position (shots don't show it)
#   scripts/vm.sh kwin   [efi|bios] 'JS'      print a KWin-script expression's value
#   scripts/vm.sh calamares [efi|bios] DOWNS  erase-disk install by keyboard (user "Test User",
#                                     login testu, password cutefish123); DOWNS = Down presses to
#                                     reach "Erase disk": 0 on an empty disk, 2 with an install
#   scripts/vm.sh wait-install [efi|bios]     wait until that install has finished
set -euo pipefail
cd "$(dirname "$0")/.."

cmd=${1:?usage: vm.sh create|start|shot|type|run|stop|destroy [efi|bios] ...}
fw=${2:-efi}
shift $(( $# >= 2 ? 2 : $# ))
VM=cutefish-$fw
DIR=$PWD/build/vm
ISO=$PWD/build/cutefish-os-26.04-amd64.iso
# Guest account for run/srun: the live user by default; set these for an installed system.
VM_USER=${VM_USER:-cutefish} VM_PASS=${VM_PASS:-}
BUS="--user --address=unix:path=/run/user/1000/bus"

grun() { VBoxManage guestcontrol "$VM" run --username "$VM_USER" --password "$VM_PASS" --wait-stdout --wait-stderr -- "$@"; }
# gsudo 'shell cmd': run as root in the guest (the password goes to sudo inside the guest).
gsudo() { grun /usr/bin/env SUDOPASS="$VM_PASS" /bin/sh -c 'printf "%s\n" "$SUDOPASS" | sudo -S -p "" /bin/sh -c "$0"' "$1"; }
keys() { VBoxManage controlvm "$VM" keyboardputscancode "$@"; }
# A KWin script can't print anywhere we can read, so it publishes its result
# as the name of Space 2, which is read back over D-Bus and then restored.
kwin_eval() {
    grun /bin/sh -c "
cat > /tmp/q.js <<'JS'
workspace.desktops[1].name = 'Q:' + String($1);
JS
run() { busctl $BUS call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s q >/dev/null
    id=\$(busctl $BUS call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript ss \$1 q | cut -d' ' -f2)
    busctl $BUS call org.kde.KWin /Scripting/Script\$id org.kde.kwin.Script run >/dev/null; sleep 0.4; }
run /tmp/q.js
busctl $BUS get-property org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager desktops | grep -o '\"Q:[^\"]*\"' | sed 's/^\"Q://; s/\"\$//'
echo \"workspace.desktops[1].name = 'Desktop 2';\" > /tmp/q.js; run /tmp/q.js"
}
wait_desktop() {
    local deadline=$(( SECONDS + ${1:-600} ))
    until grun /usr/bin/pgrep -x cutefish-shell >/dev/null 2>&1; do
        (( SECONDS < deadline )) || { echo "no desktop after ${1:-600} s" >&2; return 1; }
        sleep 5
    done
}

# Small USB sticks with NTFS and exFAT filesystems, made in the builder
# container (no mkfs tools needed on the host).
make_usb_images() {
    [[ -f $DIR/usb-ntfs.vdi && -f $DIR/usb-exfat.vdi ]] && return
    docker run --rm -v "$DIR":/out cutefish-builder bash -c '
        apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq ntfs-3g exfatprogs >/dev/null 2>&1
        truncate -s 256M /out/usb-ntfs.img /out/usb-exfat.img
        mkntfs -F -Q -L CUTEFISH-NTFS /out/usb-ntfs.img >/dev/null
        mkfs.exfat -L CF-EXFAT /out/usb-exfat.img >/dev/null
        chown '"$(id -u):$(id -g)"' /out/usb-*.img'
    for fs in ntfs exfat; do
        VBoxManage convertfromraw "$DIR/usb-$fs.img" "$DIR/usb-$fs.vdi" --format VDI >/dev/null
        rm -f "$DIR/usb-$fs.img"
    done
}

case $cmd in
create)
    [[ -f $ISO ]] || { echo "no ISO at $ISO: run scripts/build-iso.sh" >&2; exit 1; }
    mkdir -p "$DIR/shots"
    make_usb_images
    VBoxManage createvm --name "$VM" --ostype Ubuntu_64 --basefolder "$DIR" --register >/dev/null
    VBoxManage modifyvm "$VM" --memory 4096 --cpus 4 --firmware "$fw" --rtc-use-utc on \
        --graphicscontroller vmsvga --vram 256 --accelerate-3d on --monitor-count 2 \
        --nic1 nat --audio-driver default --audio-enabled on --mouse usbtablet --usb-ohci on
    VBoxManage createmedium disk --filename "$DIR/$VM/disk.vdi" --size 30720 >/dev/null
    VBoxManage storagectl "$VM" --name SATA --add sata --controller IntelAhci --portcount 2
    VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$DIR/$VM/disk.vdi"
    VBoxManage storageattach "$VM" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$ISO"
    # USB mass-storage controller emulation is in the base package (no extension pack).
    VBoxManage storagectl "$VM" --name USB --add usb --controller USB
    VBoxManage storageattach "$VM" --storagectl USB --port 0 --device 0 --type hdd --medium "$DIR/usb-ntfs.vdi"
    VBoxManage storageattach "$VM" --storagectl USB --port 1 --device 0 --type hdd --medium "$DIR/usb-exfat.vdi"
    echo "created $VM"
    ;;
start)   VBoxManage startvm "$VM" --type headless ;;
shot)
    name=${1:?shot name}
    for d in 0 1; do
        VBoxManage controlvm "$VM" screenshotpng "$DIR/shots/$VM-$name-display$d.png" $d 2>/dev/null \
            && echo "$DIR/shots/$VM-$name-display$d.png" || true   # display 1 may be off
    done
    [[ -f $DIR/shots/$VM-$name-display0.png ]]
    ;;
displays)
    # The VM has two monitors, but the guest only sees the second one after the
    # host sends a layout for it. setvideomodehint does nothing under VMSVGA;
    # setscreenlayout does, through VBoxDRMClient in the guest (from
    # virtualbox-guest-x11, started by VBoxService). See docs/setbacks.md.
    n=${1:-2} size=${2:-1280x800}
    w=${size%x*} h=${size#*x}
    layout=()
    for (( d = 0; d < 2; d++ )); do
        if (( d == 0 )); then layout+=(0 primary 0 0 "$w" "$h" 32)
        elif (( d < n )); then layout+=("$d" on $(( d * w )) 0 "$w" "$h" 32)
        else layout+=("$d" off)
        fi
    done
    VBoxManage controlvm "$VM" setscreenlayout "${layout[@]}"
    ;;
type)    VBoxManage controlvm "$VM" keyboardputstring "$*" ;;
run)     grun "$@" ;;
srun)
    # guestcontrol processes aren't in the logind session, so polkit treats them
    # as inactive. Cutefish's AppRuntime starts the command from the session.
    VBoxManage guestcontrol "$VM" run --username "$VM_USER" --password "$VM_PASS" --wait-stdout --wait-stderr -- /bin/sh -c '
        export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
        rm -f /tmp/srun.out /tmp/srun.rc
        busctl --user -- call com.cutefish.AppRuntime /AppRuntime com.cutefish.AppRuntime launchCommand sass \
            vm-srun 3 /bin/sh -c "{ $1 ; } >/tmp/srun.out 2>&1; echo \$? >/tmp/srun.rc" /tmp >/dev/null
        for _ in $(seq 1 240); do [ -e /tmp/srun.rc ] && break; sleep 0.5; done
        cat /tmp/srun.out; exit "$(cat /tmp/srun.rc 2>/dev/null || echo 124)"' srun "$*" ;;
stop)    VBoxManage controlvm "$VM" poweroff || true ;;
dvd)
    case ${1:?iso|empty} in
        iso)   medium=$ISO ;;
        empty) medium=emptydrive ;;
        *)     echo "dvd: iso or empty" >&2; exit 1 ;;
    esac
    VBoxManage storageattach "$VM" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$medium"
    ;;
disk)
    saved=$DIR/$VM/disk.path
    current=$(VBoxManage showvminfo "$VM" --machinereadable | sed -n 's/^"SATA-0-0"="\(.*\)"$/\1/p')
    case ${1:?detach|attach|fresh} in
    detach)
        [[ $current == none || -z $current ]] && { echo "no disk attached"; exit 0; }
        echo "$current" > "$saved"
        VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --medium none
        echo "detached $current"
        ;;
    attach)
        path=${2:-$(cat "$saved" 2>/dev/null || true)}
        [[ -f $path ]] || { echo "no disk to attach (give a path)" >&2; exit 1; }
        VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$path"
        echo "attached $path"
        ;;
    fresh)
        old=$current; [[ $old == none || -z $old ]] && old=$(cat "$saved" 2>/dev/null || true)
        if [[ -n $old && $old != none ]]; then
            VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --medium none 2>/dev/null || true
            VBoxManage closemedium disk "$old" --delete >/dev/null 2>&1 || rm -f "$old"
            echo "deleted $old"
        fi
        path=$DIR/$VM/disk.vdi
        VBoxManage createmedium disk --filename "$path" --size 30720 >/dev/null
        VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$path"
        echo "$path" > "$saved"
        echo "attached a new empty disk $path"
        ;;
    esac
    ;;
wait-desktop) wait_desktop "${1:-600}" ;;
install-debs)
    (( $# )) || { echo "install-debs: no debs given" >&2; exit 1; }
    grun /bin/rm -rf /tmp/debs
    VBoxManage guestcontrol "$VM" mkdir --username "$VM_USER" --password "$VM_PASS" --parents /tmp/debs
    for deb in "$@"; do
        VBoxManage guestcontrol "$VM" copyto --username "$VM_USER" --password "$VM_PASS" \
            --target-directory /tmp/debs/ "$(realpath "$deb")"
    done
    # --force-confold: conffile prompts hang a non-interactive dpkg.
    gsudo 'DEBIAN_FRONTEND=noninteractive dpkg -i --force-confold /tmp/debs/*.deb' 2>&1 | grep -vE '^\(Reading|^Preparing|^Selecting' || true
    # Restart the session (never loginctl terminate-user: it wedged the guest).
    gsudo 'systemctl restart sddm' 2>/dev/null || true
    sleep 8
    # Live, SDDM usually logs in again by itself; when it shows the greeter
    # instead (installed systems, some restarts), type the password.
    deadline=$(( SECONDS + 240 )) typed=""
    until grun /usr/bin/pgrep -x cutefish-shell >/dev/null 2>&1; do
        (( SECONDS < deadline )) || { echo "no desktop after the restart" >&2; exit 1; }
        if [[ -z $typed ]] && grun /usr/bin/pgrep -x sddm-greeter-qt6 >/dev/null 2>&1; then
            sleep 4
            [[ -n $VM_PASS ]] && VBoxManage controlvm "$VM" keyboardputstring "$VM_PASS"
            keys 1c 9c; typed=1
        fi
        sleep 3
    done
    ;;
app)
    id=${1:?app id}
    grun /usr/bin/busctl $BUS -- call com.cutefish.AppRuntime /AppRuntime com.cutefish.AppRuntime \
        launchCommand sass "$id" $# "$@" /tmp >/dev/null
    ;;
mouse)
    # ydotool injects input through uinput; KWin gives its device pointer
    # acceleration, so moves land short or long until acceleration is flat.
    if ! grun /bin/sh -c 'command -v ydotool' >/dev/null 2>&1; then
        gsudo 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -q ydotool' >/dev/null  # the ISO ships no apt lists
    fi
    gsudo 'pgrep -x ydotoold >/dev/null ||
        setsid ydotoold --socket-path=/tmp/.ydotool_socket --socket-own=1000:1000 >/dev/null 2>&1 < /dev/null &'
    sleep 2
    grun /bin/sh -c "for d in \$(busctl $BUS tree org.kde.KWin | grep -o '/org/kde/KWin/InputDevice/event[0-9]*'); do
        busctl $BUS get-property org.kde.KWin \$d org.kde.KWin.InputDevice name | grep -q ydotoold || continue
        busctl $BUS set-property org.kde.KWin \$d org.kde.KWin.InputDevice pointerAccelerationProfileFlat b true
        busctl $BUS set-property org.kde.KWin \$d org.kde.KWin.InputDevice pointerAcceleration d 0
        echo \"flat acceleration on \$d\"; done"
    ;;
click)
    # Corner first, then the move, as separate commands: in one "mousemove -a"
    # libinput sometimes merged them and the click landed elsewhere.
    grun /bin/sh -c "export YDOTOOL_SOCKET=/tmp/.ydotool_socket; ydotool mousemove -x -3000 -y -3000
        ydotool mousemove -x ${1:?x} -y ${2:?y}; ydotool click 0x40; ydotool click 0x80" >/dev/null 2>&1
    ;;
cursor) kwin_eval 'workspace.cursorPos.x + "," + workspace.cursorPos.y' ;;
kwin)   kwin_eval "${1:?JS expression}" ;;
calamares)
    # Calamares' keyboard mnemonics: Alt+N Next, Alt+I Install, Enter confirms.
    downs=${1:-0}
    K() { keys "$@"; sleep "${D:-2}"; }
    NEXT() { D=4 K 38 31 b1 b8; }
    gsudo 'pkill -x calamares' 2>/dev/null || true
    sleep 3
    grun /usr/bin/busctl $BUS -- call com.cutefish.AppRuntime /AppRuntime com.cutefish.AppRuntime \
        launchCommand sass calamares 3 sh -c "exec /usr/bin/calamares-launch-normal" /tmp >/dev/null
    sleep 15; NEXT; NEXT; NEXT
    for _ in 1 2 3; do D=0.7 K 0f 8f; done; K 39 b9           # Tab to the radio group, Space
    for (( n = 0; n < downs; n++ )); do K e0 50 e0 d0; done; K 39 b9
    NEXT
    VBoxManage controlvm "$VM" keyboardputstring "Test User"; sleep 1
    for _ in 1 2 3; do D=0.7 K 0f 8f; done
    VBoxManage controlvm "$VM" keyboardputstring "cutefish123"; sleep 1; D=0.7 K 0f 8f
    VBoxManage controlvm "$VM" keyboardputstring "cutefish123"; sleep 2
    NEXT; D=3 K 38 17 97 b8; K 1c 9c
    ;;
wait-install)
    # The install runs while Calamares' target is mounted under /tmp/calamares-root-*;
    # the last job unmounts it.
    deadline=$(( SECONDS + 1800 )) started=""
    while (( SECONDS < deadline )); do
        if grun /bin/sh -c 'grep -q calamares-root /proc/mounts' >/dev/null 2>&1; then started=1
        elif [[ -n $started ]]; then break
        fi
        sleep 10
    done
    [[ -n $started ]] || { echo "the install never started" >&2; exit 1; }
    (( SECONDS < deadline )) || { echo "the install didn't finish in 30 min" >&2; exit 1; }
    sleep 5
    log=$(gsudo 'cat /root/.cache/calamares/session.log' 2>/dev/null || true)
    if grep -qiE 'installation failed|job .* failed' <<<"$log"; then
        grep -iE 'failed|error' <<<"$log" | tail -5; exit 1
    fi
    echo "install finished"
    ;;
destroy)
    VBoxManage controlvm "$VM" poweroff 2>/dev/null || true
    sleep 2
    # --delete removes every attached disk: detach the shared USB sticks first.
    for port in 0 1; do
        VBoxManage storageattach "$VM" --storagectl USB --port $port --device 0 --medium none 2>/dev/null || true
    done
    VBoxManage unregistervm "$VM" --delete
    ;;
*) echo "unknown command $cmd" >&2; exit 1 ;;
esac
