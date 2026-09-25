# Global menu

The status bar shows the menu bar of the focused application, like macOS.

## How it works on Wayland

1. A Qt application with a native menu bar (`QMenuBar`, or `Qt.labs.platform` `MenuBar` in QML) is started under `XDG_CURRENT_DESKTOP=Cutefish`. Qt therefore loads the **cutefish** platform theme (`cutefish-qt-plugins`), which enables the native menu bar (`AA_DontUseNativeMenuBar=false`).
2. Qt's D-Bus menu bar exports the menu (`com.canonical.dbusmenu`) and registers it with `com.canonical.AppMenu.Registrar`. The status bar's `MenuImporter` provides the registrar.
3. On Wayland a window id means nothing to other processes. So the status bar looks up the active window's menu:
   - first from KWin (`org_kde_plasma_window_management` → `applicationMenuServiceName/ObjectPath`, set by apps using KDE's appmenu protocol, e.g. KDE apps through plasma-integration);
   - otherwise by the window's **PID** in the registrar (`MenuImporter::serviceForPid`).
4. GTK 3 apps export through `appmenu-gtk-module`. The session sets `GTK_MODULES=appmenu-gtk-module` (patch to `core/session/cutefish-wayland-session`), and `cutefish-core` depends on `appmenu-gtk3-module`.
5. With several displays, the menu appears on the bar of the display that holds the focused window ([multi-display.md](multi-display.md)).

## What works

| App type | Global menu |
|---|---|
| Cutefish apps with menus (Calculator, Text Editor) | yes |
| Qt 5/6 widget apps (QMenuBar) | yes |
| KDE apps (Kate, Okular, Dolphin…) | yes |
| LibreOffice with the Qt 6 look (`sudo apt install libreoffice libreoffice-qt6`) | yes |
| GTK 3 apps running through **XWayland** | yes (appmenu-gtk-module) |
| GTK 3 apps running natively on Wayland | usually no (see below) |
| GTK 4 apps | no: GTK 4 has no menu-bar export at all |
| Firefox, Thunderbird, Electron/Chromium apps | no |

For apps without an exported menu the bar still shows the application name. Its menu offers *Quit*.

## Known limitation (same as KDE Plasma)

appmenu-gtk-module announces menus through X11 window properties. A GTK app that runs as a native Wayland client has no X window, so there is nothing to announce. Plasma has the same limit. The workarounds cost more than they give: forcing `GDK_BACKEND=x11` for every GTK app loses fractional scaling and gestures. So we left GTK apps native on Wayland. A single app can be run with `GDK_BACKEND=x11 <app>` if its global menu matters more.
