#!/usr/bin/env bash
# Build the Cutefish OS live/installer ISO from the Ubuntu 26.04 archive plus
# our packages in build/repo (run scripts/build-debs.sh first).
#
# Output: build/cutefish-os-26.04-amd64.iso (hybrid: BIOS + UEFI with Secure
# Boot through Ubuntu's signed shim and GRUB).
#
# Runs in a privileged builder container: debootstrapping a root filesystem
# needs real root, and the chroot lives in the "cutefish-build" Docker volume
# (the bind-mounted workspace cannot hold device nodes or root-owned files).
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f build/repo/Packages ]] || { echo "build/repo is empty: run scripts/build-debs.sh first" >&2; exit 1; }

docker run --rm -i --privileged -v "$PWD":/ws -v cutefish-build:/build \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" cutefish-builder bash -s <<'IN_CONTAINER'
set -euo pipefail
WORK=/build/iso
ROOT=$WORK/chroot
IMAGE=$WORK/image
OUT=/ws/build/cutefish-os-26.04-amd64.iso
LABEL="CUTEFISH_2604"
MIRROR=http://archive.ubuntu.com/ubuntu

rm -rf "$WORK"
mkdir -p "$WORK" "$IMAGE"/{casper,boot/grub,EFI/boot,.disk,pool}

# Firefox comes from Mozilla: Ubuntu's "firefox" is a snap wrapper with a
# higher (epoch 1) version, so the pin must exist before apt resolves anything.
setup_hook='mkdir -p "$1/etc/apt/preferences.d" && cp /ws/packaging/files/apt/mozilla.pref "$1/etc/apt/preferences.d/mozilla"'

echo ">>> bootstrapping root filesystem"
mmdebstrap --mode=root --variant=minbase \
    --aptopt='APT::Install-Recommends "false"' \
    --setup-hook="$setup_hook" \
    --include="ubuntu-minimal,systemd-sysv,sudo,locales,language-pack-en,ca-certificates,
bash-completion,nano,less,initramfs-tools,plymouth,plymouth-label,casper,
grub-pc,grub-efi-amd64-signed,shim-signed,efibootmgr,os-prober,
cutefish-desktop,cutefish-hardware,cutefish-privacy,cutefish-live,calamares-settings-cutefish" \
    resolute "$ROOT" \
    "deb $MIRROR resolute main restricted universe multiverse" \
    "deb $MIRROR resolute-updates main restricted universe multiverse" \
    "deb http://security.ubuntu.com/ubuntu resolute-security main restricted universe multiverse" \
    "deb [trusted=yes] copy:/ws/build/repo ./" \
    "deb [signed-by=/ws/packaging/files/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    2>&1 | tee /ws/build/logs/iso-mmdebstrap.log | grep -E '^(I|E|W):' | grep -vE 'W: (Download|Target)' || true
[[ -x $ROOT/usr/bin/cutefish-session ]] || { echo "bootstrap failed, see build/logs/iso-mmdebstrap.log" >&2; exit 1; }

echo ">>> configuring the live system"
# Final APT sources: Ubuntu in deb822 form; Mozilla's come from cutefish-desktop.
: > "$ROOT/etc/apt/sources.list"
cat > "$ROOT/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: resolute resolute-updates resolute-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: resolute-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
# Removed again by the installer's rmcdrom step, so it must not belong to a package.
cp /ws/scripts/iso-cdrom.sources "$ROOT/etc/apt/sources.list.d/cdrom.sources"

cat > "$ROOT/etc/casper.conf" <<'EOF'
export USERNAME="cutefish"
export USERFULLNAME="Live session user"
export HOST="cutefish"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="Cutefish"
EOF
echo "cutefish" > "$ROOT/etc/hostname"
sed -i 's/^# *\(en_US.UTF-8\)/\1/' "$ROOT/etc/locale.gen"

mount --bind /dev "$ROOT/dev"; mount -t proc proc "$ROOT/proc"; mount -t sysfs sys "$ROOT/sys"
trap 'umount -lf "$ROOT/dev" "$ROOT/proc" "$ROOT/sys" 2>/dev/null || true' EXIT
chroot "$ROOT" /bin/bash -e <<'CHROOT'
locale-gen >/dev/null
update-locale LANG=en_US.UTF-8
if [ -f /usr/share/plymouth/themes/cutefish-logo/cutefish-logo.plymouth ]; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/cutefish-logo/cutefish-logo.plymouth 200
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/cutefish-logo/cutefish-logo.plymouth
fi
systemctl enable sddm NetworkManager bluetooth opensnitch cutefish-firewall >/dev/null 2>&1 || true
update-initramfs -u -k all
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
CHROOT
umount -lf "$ROOT/dev" "$ROOT/proc" "$ROOT/sys"; trap - EXIT

echo ">>> kernel, squashfs"
KVER=$(ls "$ROOT/lib/modules" | sort -V | tail -1)
cp "$ROOT/boot/vmlinuz-$KVER" "$IMAGE/casper/vmlinuz"
cp "$ROOT/boot/initrd.img-$KVER" "$IMAGE/casper/initrd"
echo "kernel $KVER"
chroot "$ROOT" dpkg-query -W --showformat='${Package} ${Version}\n' > "$IMAGE/casper/filesystem.manifest"
du -sx --block-size=1 "$ROOT" | cut -f1 > "$IMAGE/casper/filesystem.size"
mksquashfs "$ROOT" "$IMAGE/casper/filesystem.squashfs" -noappend -comp zstd -Xcompression-level 15 -quiet

# Empty flat repository for cdrom.sources (see iso-cdrom.sources).
: > "$IMAGE/pool/Packages"
echo "Cutefish OS 26.04 \"Resolute Raccoon\" - Release amd64 ($(date +%Y%m%d))" > "$IMAGE/.disk/info"
touch "$IMAGE/.disk/base_installable"
echo "full_cd/single" > "$IMAGE/.disk/cd_type"

echo ">>> bootloaders"
cat > "$IMAGE/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0
loadfont unicode
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Try or Install Cutefish OS" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}
menuentry "Cutefish OS (safe graphics)" {
    linux /casper/vmlinuz boot=casper nomodeset quiet splash ---
    initrd /casper/initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry "UEFI Firmware Settings" {
    fwsetup
}
fi
EOF

# UEFI: Ubuntu's signed shim loads Ubuntu's signed CD GRUB (gcdx64), which finds
# the medium by /.disk/info and reads /boot/grub/grub.cfg. Secure Boot works.
cp "$ROOT/usr/lib/shim/shimx64.efi.signed.latest" "$IMAGE/EFI/boot/bootx64.efi" 2>/dev/null \
    || cp "$ROOT/usr/lib/shim/shimx64.efi.signed" "$IMAGE/EFI/boot/bootx64.efi"
cp "$ROOT/usr/lib/shim/mmx64.efi" "$IMAGE/EFI/boot/mmx64.efi"
cp "$ROOT/usr/lib/grub/x86_64-efi-signed/gcdx64.efi.signed" "$IMAGE/EFI/boot/grubx64.efi"
EFI_IMG=$WORK/efiboot.img
dd if=/dev/zero of="$EFI_IMG" bs=1M count=10 status=none
mkfs.vfat -n EFI "$EFI_IMG" >/dev/null
mmd -i "$EFI_IMG" ::/EFI ::/EFI/boot
mcopy -i "$EFI_IMG" "$IMAGE"/EFI/boot/*.efi ::/EFI/boot/

# BIOS: GRUB El Torito image with the same grub.cfg.
grub-mkstandalone --format=i386-pc --output="$WORK/core.img" \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls all_video font gfxterm" \
    --modules="linux normal iso9660 biosdisk search" --locales="" --fonts="" \
    "boot/grub/grub.cfg=$IMAGE/boot/grub/grub.cfg"
cat /usr/lib/grub/i386-pc/cdboot.img "$WORK/core.img" > "$IMAGE/boot/grub/bios.img"

echo ">>> ISO"
(cd "$IMAGE" && find . -type f ! -name md5sum.txt ! -path './boot/grub/bios.img' -print0 | xargs -0 md5sum > md5sum.txt)
xorriso -as mkisofs -r -iso-level 3 -full-iso9660-filenames -J -joliet-long -volid "$LABEL" \
    -eltorito-boot boot/grub/bios.img -no-emul-boot -boot-load-size 4 -boot-info-table \
    --eltorito-catalog boot/grub/boot.cat --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot \
    -append_partition 2 0xef "$EFI_IMG" -appended_part_as_gpt \
    -output "$OUT" "$IMAGE" 2>&1 | grep -v '^xorriso : UPDATE' || true
chown "$HOST_UID:$HOST_GID" "$OUT"
ls -lh "$OUT"
IN_CONTAINER
(cd build && sha256sum cutefish-os-26.04-amd64.iso | tee cutefish-os-26.04-amd64.iso.sha256)
