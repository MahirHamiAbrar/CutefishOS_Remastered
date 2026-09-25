# Architecture

Cutefish OS Remastered is Ubuntu 26.04 LTS (stock signed kernel `linux-generic` 7.0) with the revived upstream Cutefish desktop (Qt 6.10, KF6, Wayland). On top of that it adds our own patches and a few new pieces.

## Where the code comes from

| Component | Source | Our changes |
|---|---|---|
| `fishui` (UI kit) | cutefishos/fishui | Every window is translucent with blur behind it by default |
| `cutefish-framework` (libcutefish: network, bluetooth, audio, screen…) | cutefishos/cutefish-framework | Hotspot fixes |
| `shell` (status bar, dock, launcher, notifications, desktop windows) | cutefishos/shell | Debian packaging, one status bar per display, global menu follows the active window's display |
| `core` (session, services, polkit agent, app runtime) | cutefishos/core | `GTK_MODULES=appmenu-gtk-module` in the session |
| `settings` | cutefishos/settings | Blur settings (strength, per-app), "separate Spaces" switch, Network Monitor page, Hotspot page back |
| `filemanager` (also provides the desktop QML module) | cutefishos/filemanager | Uses the default translucency |
| `kwin-plugins` (decoration, rounded corners, scripts, kwinrc) | cutefishos/kwin-plugins | Blur config fix, per-display Spaces on, fade for Space switching, shortcuts, depends on our KWin |
| `terminal` | cutefishos/terminal | Builds against the in-tree framework library |
| `qt-plugins`, `icons`, `wallpapers`, `sddm-theme`, `gtk-themes`, `cursor-themes`, `plymouth-theme` | cutefishos/* | none |
| `screenshot` | cutefishos/screenshot (Qt5) | Ported to Qt6 and to KWin ScreenShot2 (Wayland) |
| `calculator` | cutefishos/calculator (Qt5) | Ported to Qt6 |
| `texteditor` | cutefishs/texteditor (archived, Qt5 prototype) | Ported to Qt6/KF6 and made usable |
| KWin 6.6.6 | Ubuntu `kwin` source | Per-output virtual desktops (backport of KWin 6.7 MR !8602); `ForceBlurClasses` in the blur effect |
| `cutefish-netmonitor` | **new** (`netmonitor/`) | Native OpenSnitch UI + inbound nftables firewall |
| `cutefish-desktop`, `cutefish-hardware`, `cutefish-privacy`, `cutefish-live`, `calamares-settings-cutefish` | **new** (`packaging/`) | Meta packages, privacy defaults, live session, installer |

Exact upstream commits are pinned in `repos.lock`. Our changes are in `patches/<repo>/*.patch` and are applied by `scripts/fetch.sh`.

## Boot to desktop

```
GRUB ──► Linux 7.0 + initramfs (casper on the live ISO)
     ──► systemd ──► sddm.service
                       greeter on kwin_wayland (/etc/sddm.conf.d/10-cutefish-wayland.conf)
     ──► session "Cutefish (KWin Wayland)"  /usr/share/wayland-sessions/cutefish-wayland.desktop
           cutefish-wayland-session         exports XDG_* and GTK_MODULES, then
           kwin_wayland_wrapper --xwayland  (our KWin: per-output desktops, forced blur)
             └─ cutefish-kwin-wayland-session ─► cutefish-session
                   ├─ cutefish-services   (settings daemon: appearance, power, clipboard …)
                   ├─ cutefish-appruntime (starts and tracks applications)
                   ├─ cutefish-shell      (status bars, dock, launcher, notifications, desktops)
                   └─ XDG autostart       (cutefish-netmonitor, polkit agent, live installer …)
```

## New pieces in more detail

- **Blur:** see [blur.md](blur.md)
- **Separate Spaces per display:** see [multi-display.md](multi-display.md)
- **Global menu:** see [global-menu.md](global-menu.md)
- **Traffic monitoring and firewall:** see [privacy-netmonitor.md](privacy-netmonitor.md)
- **Drivers:** see [drivers.md](drivers.md)

## Workspace layout

```
repos.lock        pinned upstream commits
src/              upstream checkouts (gitignored), branch "remastered" = pinned commit + patches
patches/          our changes, one directory per repo (source of truth)
netmonitor/       cutefish-netmonitor source
packaging/        meta packages, Calamares settings, live-session files
docker/           Ubuntu 26.04 builder image
scripts/          fetch.sh, build-debs.sh, build-iso.sh, vm.sh, lib-commit.sh
build/            gitignored outputs: repo/ (debs), logs/, the ISO, vm/
docs/             this documentation
```
