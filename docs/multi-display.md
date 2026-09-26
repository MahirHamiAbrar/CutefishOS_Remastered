# Multiple displays: separate Spaces per display

Goal: macOS's "Displays have separate Spaces". Each monitor switches its own workspace, each monitor has its own menu bar, and the dock stays on the main display.

## What you get

| Feature | Where |
|---|---|
| Each display switches workspaces on its own | Our KWin build: per-output virtual desktops (setting `[Windows] PerOutputVirtualDesktops=true`, on by default) |
| A status bar (with global menu, clock, control centre) on every display | `cutefish-shell` creates one `StatusBar` per extra screen. The volume, Wi-Fi and battery icons are the control-centre button, so every bar shows them, as on macOS |
| The app menu appears on the display that holds the active window | `AppMenuModel.activeWindowGeometry` + `activeWindowOnThisScreen` in the status bar QML |
| System tray (app icons from StatusNotifierItem) and the notification-centre shortcut on the main display only | Tray items can register with only one watcher; the D-Bus names are owned once |
| Dock on the main display | unchanged upstream behaviour |
| Launcher opens on the display under the pointer | Asks KWin for its active output (`org.kde.KWin.activeOutputName`), which follows the pointer |
| Mission Control | KWin Overview effect, **Meta+W** (per-display after the backport) |
| Switch Space on the display under the pointer | **Meta+Ctrl+←/→**; move a window with **Meta+Ctrl+Shift+←/→** |
| Turn it off | Settings → Display → *Displays have separate Spaces* (only shown with 2+ displays) |

Two Spaces exist by default (`[Desktops] Number=2`). Add more from the Overview.

Ctrl+←/→ (the macOS shortcut) was not used on purpose: on Linux it jumps by word in every text field.

## The KWin backport

Per-output virtual desktops landed in KWin master for Plasma 6.7 ([MR !8602](https://invent.kde.org/plasma/kwin/-/merge_requests/8602), merged 2026-04-13, by Hynek Schlindenbuch). Ubuntu 26.04 and the Kubuntu backports PPA only have 6.6.6.

We cherry-picked the MR's commits onto the `v6.6.6` tag and ship the result as `kwin 4:6.6.6-0ubuntu0.1+cutefishN` (now `+cutefish2`, which adds the blur fixes). Everything built from the kwin source (`kwin-wayland`, `kwin-common`, `kwin-dev`, …) is replaced consistently, and `cutefish-kwin-plugins` depends on that version.

| Commit (upstream) | Backported | Notes |
|---|---|---|
| fa6c4a424a virtualdesktops: Add per-output desktops | yes | 7 conflicts resolved; slide.cpp/h kept at 6.6 (see below) |
| c6c0cc403b autotests: add per-output desktop tests | yes | test conflicts resolved to 6.6 (tests are not built) |
| e0cdcc6bf5 plugins/desktopchangeosd: fix per-output desktops | yes | clean |
| 5b1eee97a5 fix move/resize for window with forced desktop | yes | clean |
| a2ac8f5ee7 effect: add QuickSceneView::currentDesktop | yes | header conflict |
| 820543d767 xwayland: determine output before desktops | yes | clean |
| 13042387cf autotests/wayland: test per-output desktops | yes | clean |
| 4f87952c59 plugins/slide: create SlideEffectScreen only while active | **no** | depends on the Slide rewrite |

- **Protocol:** `org_kde_plasma_virtual_desktop` v4 (`output_entered`, `request_enter_output`) is newer than 26.04's plasma-wayland-protocols 1.20. The v4 XML is vendored into `src/wayland/` of our KWin.
- **Slide effect:** master rewrote it around the new `AnimationClock` API. We kept 6.6's Slide. Cutefish switches Spaces with the **fadedesktop** effect instead, which the MR made per-output aware (`slideEnabled=false`, `fadedesktopEnabled=true`). If a user turns Slide back on, every display slides together when one switches.

Patches: `patches/kwin/cutefish-per-output-000{1..7}-*.patch`.

When Ubuntu or Kubuntu ship KWin ≥ 6.7, drop these patches (keep the blur one), and the kwinrc settings keep working unchanged.

## Shell changes

- `src/shell/src/shell.cpp`: `syncSecondaryStatusBars()` creates and removes bars on screen add, remove and primary change.
- `src/shell/src/statusbar/statusbar.{h,cpp}`: `StatusBar(engine, screen)`. The primary bar owns the D-Bus adaptor and the app-menu registrar.
- `src/shell/src/core/services/screenhelper.*` and `statusbar/statusbarforegroundhelper.*`: `targetScreen` property, so each bar samples its own wallpaper strip and uses its own work area.
- `src/shell/src/core/wayland/kwinwaylandinterface.*`: window geometry from the Plasma window-management protocol.
- `src/shell/src/statusbar/qml/main.qml`: tray only on the primary bar; app menu only where the active window is.
- `src/shell/src/launcher/launcher.cpp` (`patches/shell/0002-*`): before showing, the launcher moves to the screen KWin reports as active, keeps the dock margin only on the dock's screen, and closes if its screen is unplugged. A Wayland client can't read the global pointer position; KWin moves its active output with every pointer motion.

## Testing it

KWin's D-Bus `VirtualDesktopManager.current` is the Space on the **active** output, so it reads the same whether Spaces are per display or global, and can't be used as a check. `scripts/test-spaces.sh` loads a KWin script instead. The script switches only the second display (`workspace.setCurrentDesktopForScreen`) and checks that the first display kept its Space:

```sh
scripts/vm.sh start efi
scripts/test-spaces.sh efi   # PASS Virtual-1: Desktop 1 -> Desktop 1, Virtual-2: Desktop 1 -> Desktop 2
```

The result comes back as the name of the first Space, since that's the only string a script can publish on D-Bus. The name is restored afterwards. Screenshots of both displays go to `build/vm/shots/*-spaces-test-*`. With `PerOutputVirtualDesktops=false` the same test reports FAIL, because both displays switch.

The VM's second monitor appears only when the host sends a layout (`scripts/vm.sh displays efi 2`), and only if `VBoxDRMClient` runs in the guest. See [setbacks.md](setbacks.md) §17.
