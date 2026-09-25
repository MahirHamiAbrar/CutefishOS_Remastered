# Cutefish OS Remastered: documentation

Cutefish OS brought back on **Ubuntu 26.04 LTS** (stock kernel 7.0), with the revived upstream Cutefish desktop on **Qt 6 / KF6 / Wayland**, plus:

- macOS-style blur behind windows by default, and per-app blur for any application;
- **separate workspaces (Spaces) per display**, a status bar on every display, and a global menu that follows the focused window;
- a **network monitor**: every new outgoing connection is asked about per app (OpenSnitch with a native Cutefish UI), incoming connections are refused and logged, and everything is visible in Settings;
- privacy defaults: no snap, no crash or usage reporting, Firefox from Mozilla without telemetry, random Wi-Fi MACs;
- drivers for display, input, Wi-Fi, hotspot, Bluetooth, sound, charging, NTFS/exFAT/USB/MTP, printers and firmware; proprietary drivers through `ubuntu-drivers`;
- a live/installer ISO (Calamares, BIOS + UEFI Secure Boot).

## Read first

| Document | What's in it |
|---|---|
| [wayland-research.md](wayland-research.md) | X11 or Wayland? (short answer: upstream already moved to Wayland; we stayed there) |
| [architecture.md](architecture.md) | Components, where each comes from, what we changed, boot flow |
| [building.md](building.md) | How to fetch, build the packages (Modal or Docker) and the ISO |
| [testing.md](testing.md) | VirtualBox harness and test plan |
| [setbacks.md](setbacks.md) | Every problem we hit, why, and how it was solved |
| [known-issues.md](known-issues.md) | What still doesn't work, or only partly works |

## Features

| Document | Topic |
|---|---|
| [blur.md](blur.md) | Blur and translucency |
| [multi-display.md](multi-display.md) | Per-display Spaces (KWin 6.7 backport), per-display status bars |
| [global-menu.md](global-menu.md) | Global menu on Wayland |
| [privacy-netmonitor.md](privacy-netmonitor.md) | Network monitor, firewall, privacy defaults |
| [drivers.md](drivers.md) | Hardware support |
| [qt6-porting.md](qt6-porting.md) | Qt 5 → Qt 6 ports (screenshot, calculator, text editor) |
| [hardware-checklist.md](hardware-checklist.md) | What to test on a real laptop |

## Quick start

```sh
docker build -t cutefish-builder docker/
scripts/fetch.sh
MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py   # or scripts/build-debs.sh
scripts/build-iso.sh
scripts/vm.sh create efi && scripts/vm.sh start efi
```
