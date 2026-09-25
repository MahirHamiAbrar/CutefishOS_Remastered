# Qt 6 port

Upstream Cutefish already moved its core components to Qt 6.10 / KF6 (fishui, framework, shell, core, settings, filemanager, kwin-plugins, qt-plugins, terminal, sddm-theme). Three apps were still on Qt 5, and we ported them.

## screenshot (Qt 5 → Qt 6, X11 → Wayland)

| Qt 5 / X11 code | Qt 6 / Wayland replacement | Why |
|---|---|---|
| `find_package(Qt5 …)`, `qt5_create_translation` | `find_package(Qt6 …)`, `qt6_add_translation` | |
| `QScreen::grabWindow(0)` | `org.kde.KWin.ScreenShot2.CaptureScreen(name, {native-resolution: true}, pipe fd)`; raw pixels are read from a pipe, and `width/height/stride/format` from the reply | A Wayland client cannot read the screen |
| `Qt::X11BypassWindowManagerHint` | `showFullScreen()` + `requestActivate()` | X11-only flag |
| `/tmp/cutefish-screenshot.png` | `$XDG_RUNTIME_DIR/cutefish-screenshot.png` | `/tmp` is shared and predictable |
| `import QtGraphicalEffects 1.0` (unused) | removed | module gone in Qt 6 |
| `debian/control`: `qtbase5-dev`, `qml-module-*` | `qt6-base-dev`, `qml6-module-*`, `debhelper-compat (= 13)` | |

KWin only serves ScreenShot2 to apps whose `.desktop` file declares `X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2`, so `cutefish-screenshot.desktop` now does.

## calculator (Qt 5 → Qt 6)

- CMake: Qt 6 packages, C++17, `qt6_add_translation`.
- `main.cpp`: removed `Qt::AA_EnableHighDpiScaling`, which is always on in Qt 6.
- Packaging: Qt 6 build and runtime dependencies (`qml6-module-qt-labs-platform` for its native menu bar, which also shows up in the global menu).

## texteditor (Qt 5/KF5 → Qt 6/KF6, and finished)

The only surviving copy of the source (`cutefishs/texteditor`, archived) was an unfinished prototype.

- `QTextCodec` (removed in Qt 6) → `QStringConverter::encodingForData()` (BOM detection) + `QStringDecoder`, UTF-8 by default.
- `KF5SyntaxHighlighting` → `KF6SyntaxHighlighting`.
- It opened a hard-coded `file:///home/cutefish/桌面/winepath` on start. Now files from the command line (`Exec=cutefish-editor %F`) are opened, and an empty tab otherwise.
- Added a File menu (New Tab, Open, Save, Save As, Close Tab, Quit, with standard shortcuts) using `Qt.labs.platform` `MenuBar`, so it appears in the global menu, plus open/save dialogs.
- A call to a `showPassiveNotification` that doesn't exist was removed. Untitled tabs are called "Untitled".
- Added install rules (there were none), a binary named `cutefish-editor` matching the `.desktop` file, and an icon that exists (`accessories-text-editor`).
- QML signal handlers use the Qt 6 form (`function onNewPath(path)`, `onDropped: (drop) => …`), because implicit parameter injection is deprecated.

## Where upstream's Qt 6 port is incomplete

- `terminal` expects a `CutefishFramework` CMake package and `FishUI.HeaderButton` that are not published yet. We worked around both (setback 7).
- Qt 6 QML still accepts versioned imports (`import QtQuick 2.12`), so they were left as they are.
