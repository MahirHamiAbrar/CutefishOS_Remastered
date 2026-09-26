# Drivers and hardware support

Principle: use Ubuntu's stock, signed kernel and firmware (Secure Boot keeps working), and add only what a desktop needs. Proprietary drivers come from `ubuntu-drivers`, exactly like on Ubuntu. Everything is pulled in by the `cutefish-hardware` meta package (`packaging/debian/control`).

| Area | Packages | Notes |
|---|---|---|
| Kernel | `linux-generic` (7.0 series), `linux-firmware`, `intel-microcode`, `amd64-microcode` | Signed Ubuntu kernel, updates through normal apt |
| Graphics | `libgl1-mesa-dri`, `mesa-vulkan-drivers` | Intel, AMD, nouveau, virtio/VMware/VirtualBox |
| Video decoding | `mesa-va-drivers`, `intel-media-va-driver`, `va-driver-all` | VA-API for Firefox and mpv |
| NVIDIA / Broadcom Wi-Fi / other proprietary | `ubuntu-drivers-common`, `dkms` | The installer runs `ubuntu-drivers install` when online. Later: `sudo ubuntu-drivers install`. NVIDIA 535+ works on Wayland; the 470 legacy driver does not (no GBM), so those cards use nouveau. |
| Keyboard, mouse, touchpad, touchscreen | libinput through KWin (always present) | Touchpad gestures and options in Settings → Touchpad |
| Wi-Fi | `network-manager`, `wpasupplicant`, `wireless-regdb`, `iw`, `rfkill` | Settings → WLAN |
| Wi-Fi hotspot | `dnsmasq-base` (NetworkManager "shared" mode) | Settings → Hotspot (re-enabled and fixed, see setback 11). The inbound firewall lets hotspot DHCP/DNS through. |
| Mobile broadband | `modemmanager` | |
| Bluetooth | `bluez`, `bluez-obexd`, `libspa-0.2-bluetooth` | Pairing in Settings → Bluetooth; Bluetooth audio through PipeWire; file transfer through OBEX |
| Sound | PipeWire (`pipewire-pulse`, `wireplumber`, `pipewire-alsa`), `firmware-sof-signed`, `alsa-ucm-conf` | SOF firmware and UCM profiles are needed by most laptops from 2019 on |
| Battery and charging | `upower`, `power-profiles-daemon`, `acpid` | Battery level, charging state, time left and history in the status bar and Settings → Battery; power profiles in Settings → Power |
| Thermal and sensors | `thermald`, `iio-sensor-proxy` | Screen auto-rotation and ambient light on convertibles |
| NTFS | in-kernel `ntfs3` driver (read/write) + `ntfs-3g` (tools: `mkntfs`, `ntfsfix`) | udisks2 mounts NTFS with `ntfs3` |
| exFAT / FAT | in-kernel exFAT and vfat + `exfatprogs`, `dosfstools` | |
| USB drives | `udisks2` + KF6 Solid in the file manager | Auto-mount, eject |
| Phones (MTP), network shares | `kio-extras`, `gvfs-backends` | |
| Printers | `cups`, `printer-driver-all`, `system-config-printer-common` | |
| Firmware updates | `fwupd` | `fwupdmgr update` (LVFS) |
| Virtual machines | `virtualbox-guest-utils`, `virtualbox-guest-x11`, `spice-vdagent`, `qemu-guest-agent` | Resize, extra monitors, clipboard, clean shutdown; they do nothing on real hardware. `virtualbox-guest-x11` is there for VBoxDRMClient, which VBoxService starts by itself inside VirtualBox |

## What we verified

In VirtualBox: see [testing.md](testing.md). Real hardware (charging, specific Wi-Fi/Bluetooth chips, NVIDIA, suspend) needs a real machine: see [hardware-checklist.md](hardware-checklist.md).
