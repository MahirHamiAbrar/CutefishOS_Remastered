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
#   scripts/vm.sh displays [efi|bios] N [WxH]  turn on N displays side by side (default 2, 1280x800)
#   scripts/vm.sh stop   [efi|bios]
#   scripts/vm.sh destroy [efi|bios]
set -euo pipefail
cd "$(dirname "$0")/.."

cmd=${1:?usage: vm.sh create|start|shot|type|run|stop|destroy [efi|bios] ...}
fw=${2:-efi}
shift $(( $# >= 2 ? 2 : $# ))
VM=cutefish-$fw
DIR=$PWD/build/vm
ISO=$PWD/build/cutefish-os-26.04-amd64.iso

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
            && echo "$DIR/shots/$VM-$name-display$d.png"
    done
    ;;
displays)
    # The VM has two monitors, but the guest only sees the second one after the
    # host sends a layout for it. setvideomodehint does nothing under VMSVGA;
    # setscreenlayout does, through VBoxDRMClient in the guest
    # (cutefish-vbox-drmclient.service). See docs/setbacks.md.
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
run)     VBoxManage guestcontrol "$VM" run --username cutefish --password "" --wait-stdout --wait-stderr -- "$@" ;;
stop)    VBoxManage controlvm "$VM" poweroff || true ;;
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
