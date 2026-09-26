# qt-plugins

`cutefish-qt-plugins`: the Qt plugins that make every Qt application follow the Cutefish look, whether or not it uses FishUI. Upstream is cutefishos/qt-plugins. API reference: [api/qt-plugins.md](api/qt-plugins.md).

## Layout

```
platformtheme/   QPlatformThemePlugin "cutefish"   (QT_QPA_PLATFORMTHEME=cutefish, set by the session)
  platformtheme.*      PlatformTheme : QGenericUnixTheme
  hintsettings.*       reads ~/.config/cutefishos/theme.conf and watches it
  systemtrayicon.*     QSystemTrayIcon → StatusNotifierItem on D-Bus
  statusnotifier/      the StatusNotifierItem D-Bus adaptor and types
widgetstyle/     QStylePlugin "cutefish"            (Qt Widgets style, derived from Phantom style)
  basestyle.*, phantomcolor.*, pstyleplugin.*
imageformat/     QImageIOPlugin "svg" using librsvg  (better SVG rendering than QtSvg for icons)
```

## How it works

The session exports `QT_QPA_PLATFORMTHEME=cutefish` (core, `session/application.cpp`), so every Qt 6 app loads `PlatformTheme` at startup.

- **Hints** (`HintsSettings`) come from `theme.conf`, the file core's Appearance service writes:
  - `SystemIconThemeName`: `IconTheme`. For the default `Cutefish` theme it follows dark mode (`Cutefish-Light` or `Cutefish-Dark`).
  - `SystemIconFallbackThemeName`: `Cutefish-Light`.
  - `StyleNames` is `cutefish`, so Widgets apps use the style from `widgetstyle/`.
  - Fonts: the system font and point size (`Font`, `FontSize`) and the fixed font (`FixedFont`). The fallbacks when unset are Inter and JetBrains Mono.
- **Live changes:** a `QFileSystemWatcher` on `theme.conf` re-reads it and emits `systemFontChanged`, `iconThemeChanged` or `darkModeChanged`. `PlatformTheme` then:
  - sets the new application font;
  - refreshes the icon theme;
  - on dark mode, recreates the `cutefish` style so the palette updates.
- **Qt Quick Controls:** `setQtQuickControlsTheme()` picks the `Fish` style (from FishUI), unless `QT_QUICK_CONTROLS_STYLE` is set. KDE's own apps (`systemsettings`, `plasma*`) get Plasma/Breeze instead.
- **Tray icons:** `createPlatformSystemTrayIcon()` returns a `SystemTrayIcon` that registers a `StatusNotifierItem` with `org.kde.StatusNotifierWatcher`. The shell's status bar hosts it.
- **Menu bar:** `AA_DontUseNativeMenuBar` is off, so apps export their menus for the global menu ([../global-menu.md](../global-menu.md)).

## Making changes

- **A new appearance setting that Qt apps should follow:**
  1. add the key where core writes `theme.conf`;
  2. read it in `HintsSettings` and add a signal;
  3. react in `PlatformTheme`.

  FishUI apps get settings through `FishUI.Theme` instead ([fishui.md](fishui.md)); plain Qt Widgets and third-party Qt Quick apps only see what this plugin applies.
- **Widget colours and metrics:** `widgetstyle/basestyle.cpp` and `phantomcolor.cpp`.
- **Testing without a session:** `QT_QPA_PLATFORMTHEME=cutefish <any Qt app>`.
