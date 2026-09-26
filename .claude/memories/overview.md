# Overview

## Goal (from the user)
Bring Cutefish OS back on **Ubuntu 26.04 LTS** ("resolute"), stock kernel (linux-meta 7.0.0-x), Qt 6, **Wayland only**, and ship it as a **bootable ISO plus .debs**. The system should be functional and "bugless". Required features:
- macOS-style **blur**, on by default, plus a per-app toggle (Settings → Appearance → Blur).
- **Traffic monitoring**, incoming and outgoing: OpenSnitch prompts *and* a native Cutefish monitor (`netmonitor/`, a Qt6 gRPC UI for the OpenSnitch daemon, plus a Settings page).
- **Multiple displays with separate Spaces per display** (macOS-like), via a KWin backport.
- A working **global menu** (Qt/KDE apps; native Wayland GTK/Firefox/Electron can't export menus, which is documented).
- Hardware: display, keyboard, mouse/touchpad, Wi-Fi, **hotspot**, Bluetooth, charging/battery, **NTFS** (in-kernel ntfs3), exFAT, USB.
- Testing in **VirtualBox 7.2** (QEMU is not available on the host).
- Everything documented in `docs/`, **setbacks included**.

The approved plan is in `~/.claude/plans/okay-a-few-years-glimmering-dragonfly.md` on the user's laptop; `docs/` covers the same ground.

## Decisions the user made (don't reopen these)
- Code base: the **revived upstream** `github.com/cutefishos` (Qt6/KF6/Wayland), not the dead `cutefishos-ubuntu` Qt5 forks. The forks are used only for `texteditor` (really `cutefishs/texteditor`) and `cutefish-calamares-settings`.
- Deliverable: ISO + debs. Build: Docker `ubuntu:26.04` (heavy compiles on Modal).
- Kernel: stock Ubuntu. Restricted drivers through `ubuntu-drivers` (run by the installer when online).
- Blur: Cutefish apps blur by default (FishUI), plus a per-app force list.
- Network monitor: OpenSnitch 1.6.9 from universe + our native UI (not the PyQt5 UI).
- Per-display workspaces: backport KWin MR !8602 to 6.6.6.
- Browser: Firefox from Mozilla's APT repo (no snap).
- Wayland only (research: `docs/wayland-research.md`).
- 2026-09-26: Docker Desktop may be restarted by the agent.
- 2026-09-26: OpenSnitch `DefaultAction` stays **allow**; the gap while a prompt is open is documented (`docs/known-issues.md`).
- 2026-09-26: the live ISO gets an OpenSnitch **allow rule for the installer** (`/usr/bin/calamares` and `/tmp/calamares-root-*/…`), shipped in `cutefish-live`, so it's purged after install.

## Architecture in one page
- **Session:** SDDM (Cutefish theme) → `cutefish-wayland-session` (core) → `kwin_wayland` (our build) → `cutefish-session` starts shell (status bar per display, dock on primary, launcher, desktop), settings daemon (`cutefish-services`), polkit agent, AppRuntime, autostart (netmonitor, live installer).
- **Lock screen:** kscreenlocker with our QML theme `org.cutefish.desktop` (Plasma/Shell KPackage in `packaging/files/lockscreen`), selected by `PLASMA_DEFAULT_SHELL`.
- **Blur:** FishUI windows are translucent and ask for blur. Per-app force blur is `kwinrc [Effect-blur] ForceBlurClasses` (our KWin patch) plus a `kwinrulesrc` opacity rule `cutefish-blur-<class>` (90 %/85 %) written by Settings.
- **Spaces per display:** the KWin backport, `kwinrc [Windows] PerOutputVirtualDesktops=true` (Settings toggle), fadedesktop effect instead of Slide.
- **Privacy:** `opensnitchd` with eBPF modules; `cutefish-netmonitor` listens on `unix:///tmp/osui.sock`, shows prompts (30 s, then deny), logs to SQLite, exposes D-Bus `com.cutefish.NetMonitor`. Inbound: `cutefish-firewall.service` loads `/etc/cutefish-firewall.nft` (policy drop, log prefix `cutefish-in:`); Settings reads it with `journalctl -k`, which needs the `adm` group. Preset allow rules for system services live in `netmonitor/data/opensnitch-rules/` and are copied to `/etc/opensnitchd/rules` by postinst. `cutefish-privacy` removes apport/whoopsie/snapd etc. and turns off NM connectivity checks.
- **Meta packages** (`packaging/`, source `cutefish-meta`): `cutefish-desktop`, `cutefish-hardware`, `cutefish-privacy`, `cutefish-live`, `calamares-settings-cutefish`.
- **Installer:** Calamares 3.3.14 (Ubuntu) + our settings/branding (`packaging/calamares/`). It unpacks the squashfs with rsync, then purges the live packages and runs `ubuntu-drivers install || true`.
- **ISO:** `scripts/build-iso.sh`: mmdebstrap rootfs → casper squashfs → xorriso hybrid ISO (UEFI through Ubuntu's signed shim/GRUB; BIOS through a grub-mkstandalone El Torito image).
