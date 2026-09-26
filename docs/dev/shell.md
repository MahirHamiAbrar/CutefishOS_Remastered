# shell

`cutefish-shell`: the desktop shell. One process contains the status bar (one per display), the dock, the launcher, the desktop surfaces (wallpaper and icons) and the notification server. Upstream is cutefishos/shell, which merged the old separate `statusbar`, `dock`, `launcher` and `notificationd` programs.

Our changes:
- Debian packaging;
- a status bar on every display;
- the global menu follows the focused window's display.

API reference: [api/shell.md](api/shell.md).

## Layout

```
src/main.cpp, shell.{h,cpp}  QApplication; Shell owns one QQmlEngine and every component
src/core/                    shared by all components ("core" static library)
  wayland/kwinwaylandinterface.*  KWayland client: PlasmaWindowManagement (window list),
                                  PlasmaShell, layer-shell; the running windows for dock and menus
  wayland/strutspacer.*           reserves screen edges (work area) for the bar and dock
  window/shellsurface.*           QQuickWindow base for panels: role (panel, overlay, desktop…),
                                  panel behaviour, screen binding
  window/plasmasurface.*          keeps an org_kde_plasma_shell surface on a QWindow across remaps
  window/popupwindow.*            popups anchored to panel items
  services/activity.*             the active window: app id, title, screen
  services/applicationresolver.*  window → .desktop entry (icon, name)
  services/processprovider.*, screenhelper.*
src/statusbar/   StatusBar: top bar, global menu, system tray, Control Center, clock, battery, user menu
  appmenu/         global menu: com.canonical.AppMenu.Registrar + DBusMenu importer (AppMenuModel)
  libdbusmenuqt/   DBusMenu client (from KDE)
  systemtray/      StatusNotifierWatcher + host: tray icons
  qml/main.qml, ControlCenter.qml, SystemTray.qml, …
src/dock/        DockWindow, ApplicationModel (pinned + running apps), DockSettings, TrashManager, autohide
src/launcher/    Launcher: full-screen app grid (LauncherModel, PageModel, AppManager)
src/desktop/     DesktopManager: one DesktopSurface per screen (wallpaper + icons from Files' desktop module)
src/notification/ NotificationServer (org.freedesktop.Notifications), popups, history, Do Not Disturb
data/cutefish-dock-list.conf   default pinned apps → /etc/cutefish-dock-list.conf
protocols/       wlr-layer-shell, xdg-shell XML
```

It builds `../cutefish-framework/applications` (static) as well, so the framework checkout must sit next to it.

## Startup

`Shell::registerServices()` claims the bus names below; if any is taken, another shell is running and this one exits. `Shell::start()` then creates, in this order:
1. **the dock**, created but mapped last: the desktop is an ordinary full-screen window, and mapping it later could cover the panels;
2. **the desktops**;
3. **the notification manager**, which the status bar's QML reads from the root context;
4. **the primary status bar**, plus one secondary bar per extra screen (`syncSecondaryStatusBars`, re-run on screen add, remove and primary change);
5. **the launcher**.

All components share one `QQmlEngine`. Each registers its C++ types in its own `qmltypes.cpp`.

## D-Bus services

| Service / path | Interface | Methods, properties, signals |
|---|---|---|
| `com.cutefish.Shell /Shell` | n/a | Liveness only |
| `com.cutefish.Statusbar /Statusbar` | `com.cutefish.Statusbar` | `setBatteryPercentage(bool)`, `setTwentyFourTime(bool)` |
| `com.cutefish.Dock /Dock` | `com.cutefish.Dock` | `add(desktopFile)`, `remove(desktopFile)`, `pinned(desktopFile)`, `setDirection`, `setIconSize`, `setVisibility`; properties `primaryGeometry`, `direction`, `visibility` |
| `com.cutefish.Launcher /Launcher` | `com.cutefish.Launcher` | `show()`, `hide()`, `toggle()` |
| `com.cutefish.Notification /Notification` | `com.cutefish.Notification` | `showWindow()`, `setDoNotDisturb(bool)`, property `doNotDisturb` |
| `org.freedesktop.Notifications` | freedesktop spec | The notification server |
| `org.kde.StatusNotifierWatcher` | KDE SNI | The tray |
| `com.canonical.AppMenu.Registrar` | AppMenu | Apps register their menus here (global menu) |

Settings uses Dock, Statusbar and Notification. Everything else is for apps.

## How the main pieces work

- **Window list:** `KWinWaylandInterface` binds KWin's `org_kde_plasma_window_management`. KWin serves it only to clients whose desktop file it finds, which needs `XDG_MENU_PREFIX` (see [core.md](core.md)). The dock's running indicators, the global menu's "active window" and window activation all come from there.
- **Panels:** the status bar and dock are `ShellSurface`s with the Plasma shell role `Panel`. Their `StrutSpacer`s reserve work area, so maximized windows stop at them. The `cutefishlauncher` KWin script puts the launcher back on the whole screen ([kwin-plugins.md](kwin-plugins.md)).
- **Global menu:** apps export DBusMenu, Qt apps through the platform theme and GTK 3 apps through `appmenu-gtk-module`. `AppMenuModel` follows `Activity` (the active window) and shows its menu in the status bar of the screen that window is on ([../global-menu.md](../global-menu.md)).
- **Dock:**
  - `ApplicationModel` merges pinned apps with running windows;
  - pins are stored in `~/.config/cutefishos/dock_pinned.conf`, seeded from `/etc/cutefish-dock-list.conf` on first run;
  - size, direction and visibility (always, autohide, smart hide) are in `~/.config/cutefishos/dock.conf`;
  - launching goes through AppRuntime.
- **Desktop:** `DesktopManager` makes one `DesktopSurface` per screen. It shows the wallpaper (from `Cutefish.Appearance`) and the icon grid from Files' `org.cutefish.filemanager.desktop` QML module ([filemanager.md](filemanager.md)).
- **Notifications:** `NotificationServer` implements the freedesktop spec, `NotificationPopups.qml` shows them, and `HistoryModel` feeds the Notification Center. Do Not Disturb suppresses popups.
- **Control Center** (`statusbar/qml/ControlCenter.qml`):
  - Wi-Fi, Bluetooth, dark mode, screenshot, volume, brightness and media;
  - it uses the framework's QML modules;
  - screenshot runs `cutefish-screenshot -d 500`.

## Making changes

- **A status bar item:** QML in `src/statusbar/qml/`, listed in `statusbar.qrc`. C++ helpers go in `src/statusbar/` and are registered in `statusbar/qmltypes.cpp`.
- **Anything per screen:** follow `syncSecondaryStatusBars` and `DesktopManager`. Screens come and go at runtime.
- **Restarting the shell while testing:** `pkill -x cutefish-shell`, then start it again through AppRuntime (`scripts/vm.sh srun … 'cutefish-shell'`), so it runs inside the session. The session doesn't restart it on its own.
