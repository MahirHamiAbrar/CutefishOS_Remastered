# Real-hardware checklist

A VM can't test real chips, batteries or GPUs. Please run through this on a laptop (booting the live USB is enough for most items) and report failures with the command output shown.

Write the ISO to a USB stick with `sudo dd if=cutefish-os-26.04-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync`, or use any image writer.

| Area | Test | If it fails, send |
|---|---|---|
| Boot | Boots with Secure Boot **on** | photo of the error |
| Display | Correct resolution, brightness keys, external monitor (HDMI/USB-C) | `journalctl -b -u sddm`, `kscreen-doctor -o` |
| NVIDIA | After install: `sudo ubuntu-drivers install`, reboot, session starts | `ubuntu-drivers devices`, `journalctl -b -p err` |
| Keyboard | Typing, layout switch, function/media keys | `journalctl --user -b -p warning` |
| Touchpad | Tap-to-click, two-finger scroll, gestures; Settings → Touchpad | `libinput list-devices` |
| Wi-Fi | Scan, connect with a password, reconnect after suspend | `nmcli dev`, `journalctl -b -u NetworkManager` |
| Hotspot | Settings → Hotspot (8+ character password), phone connects and has internet | `nmcli con show --active`, same journal |
| Bluetooth | Pair headphones (audio plays), pair a mouse, send a file | `bluetoothctl show`, `journalctl -b -u bluetooth` |
| Charging | Status bar battery icon changes when plugging in/out; percentage and time; Settings → Battery history | `upower -d` |
| Power | Power profiles in Settings → Power; suspend and resume on lid close | `powerprofilesctl`, `journalctl -b -1 -p err` |
| Sound | Speakers, headphone jack, microphone, HDMI audio | `pactl info`, `aplay -l` |
| Webcam | Firefox → webcam test site | `ls /dev/video*` |
| USB stick | NTFS and exFAT sticks mount and are writable; eject | `udisksctl status`, `journalctl -b | grep -i ntfs` |
| Phone | Plug in an Android phone (file transfer mode) → file manager | `lsusb` |
| Printer | Settings / system-config-printer finds it | `lpstat -v` |
| Firmware | `fwupdmgr get-updates` | output |
| Privacy | Firefox's first connection shows the Network Monitor prompt | `systemctl status opensnitch`, `journalctl --user -b | grep netmonitor` |
