# fishui

`fishui`: the UI toolkit every Cutefish app is built with. It ships two QML modules:
- **`FishUI`**: the window, theme, units and Cutefish-specific controls, plus C++ helpers for blur, shadows, icons and window moving;
- **`Fish`**: a Qt Quick Controls 2 style, so plain `QtQuick.Controls` (`Button`, `CheckBox`, …) look like Cutefish. The platform theme selects it ([qt-plugins.md](qt-plugins.md)).

Upstream is cutefishos/fishui (Qt 6 port). We added the translucent default, live window opacity and radius, and the controls Terminal expects (setback 31). API reference, with every type and property: [api/fishui.md](api/fishui.md).

## Layout

```
src/fishui.{h,cpp}       QQmlExtensionPlugin: registers everything below under "FishUI 1.0"
src/fishui.qrc           the controls/*.qml files, compiled into the plugin (qrc:/fishui/kit/)
src/controls/            FishUI QML: Window, Theme, Units, menus, dialogs, tabs, …   + qmldir
src/Fish/                the "Fish" Qt Quick Controls style                          + qmldir
src/thememanager.*       FishUI.Core ThemeManager singleton: live appearance from core
src/platforms/linux/
  windowhelper.*         move, resize, minimize through the compositor
  blurhelper/            WindowBlur, via KWayland org_kde_kwin_blur
  shadowhelper/          WindowShadow, via KWayland org_kde_kwin_shadow (rendered box shadow)
src/iconitem.*, iconthemeprovider.*, managedtexturenode.*  theme icons in QML ("image://icontheme/<name>")
src/desktop/             MenuPopupWindow + platform menu glue for native-looking popups
src/dpi.*                attached Dpi.ratio
src/wheelhandler.*       smooth wheel scrolling for Flickables
src/qqmlsortfilterproxymodel.*  SortFilterProxyModel for QML
```

Installed to `qt6/qml/FishUI/` (the plugin, `qmldir` and the `controls/` sources) and `qt6/qml/Fish/`.

## The appearance chain

```
cutefish-services (core)  ──D-Bus──►  Cutefish::Appearance (cutefish-framework)
        ──►  FishUI.Core ThemeManager (C++ singleton)
        ──►  FishUI.Theme (QML singleton, Theme.qml)  ──►  every control's bindings
```

`ThemeManager` wraps the framework's `Appearance` class and forwards its change signals. `Theme.qml` binds to it:
- `darkMode`, `blurEnabled`, `windowOpacity`, `windowRadius`, `highlightColor` (the accent), `fontFamily` and `fontSize` all come from there;
- the fixed palette (`backgroundColor`, `textColor`, …) switches on `darkMode`.

Everything updates live. **Never hard-code colours, radii or spacing in an app:** use `FishUI.Theme.*` and `FishUI.Units.*` (`smallSpacing`, `largeSpacing`, `iconSizes`, `gridUnit`).

## `FishUI.Window`: the application window

Every app's root item. It is a frameless, transparent `QtQuick.Window` that draws its own frame:
- **Background:** a rounded `Rectangle` (`windowRadius`, square when maximized) in `Theme.backgroundColor`. With `blurBehind` its opacity is `Theme.windowOpacity`, 0.04 lower in dark mode, and never below 0.3. Without blur it is opaque. It has a hairline border.
- **Blur:** `FishUI.WindowBlur { view: control; windowRadius; enabled: blurBehind }` asks KWin to blur behind the window's rounded shape.
- **Shadow:** `FishUI.WindowShadow`, stronger while the window is active.
- **Header:** `header` / `headerItem` hold the title area, which drags the window (`helper.startSystemMove`). The window buttons are aligned by `windowButtons*` and coloured for `headerDarkMode`.
- **Resizing:** invisible edge and corner `MouseArea`s call `helper.startSystemResize(window, edges)`.
- **Content:** children go into the content area below the header (`default property alias content`).

Useful properties:
- `blurBehind` (defaults to `Theme.blurEnabled`), `windowRadius`, `minimizeButtonVisible`;
- `background`, `header` and `headerBackground` for styling;
- `contentTopMargin`, `isMaximized`, `isFullScreen`.

Functions: `toggleMaximized()` and `showPassiveNotification(message, timeout, actionText, callback)`.

Don't add another `WindowBlur`, or a fixed `background.opacity`, in an app: both fight the system setting. A panel that should look denser than the window (a sidebar, say) should put a lightly tinted `Rectangle` on top. Settings and Files use `opacity: blurEnabled ? 0.3 : 0.7` for theirs.

## Other controls (FishUI 1.0)

| Type | Use |
|---|---|
| `Theme`, `Units` | Singletons: palette, fonts, radii; spacing and icon sizes |
| `Label` | Text in `Theme.textColor` and the system font |
| `RoundImageButton` | Round icon button: `source`, or `iconName` (theme icon) + `iconColor` |
| `Menu`, `MenuItem`, `MenuSeparator`, `DesktopMenu`, `MenuSurface` | Popup menus in their own translucent window (`MenuPopupWindow`) |
| `ComboBox`, `ComboBoxMenu` | Combo box with a FishUI popup |
| `TabBar`, `TabButton`, `TabCloseButton`, `TabView` | Tabs (Terminal, Text Editor) |
| `AboutDialog`, `Dialog`, `ConfirmDialog` + `ConfirmDialogButton` | Dialog windows. `ConfirmDialog` has `parentWindow` (centres on it, transient), `showOnCompleted` and `open()` |
| `Toast`, `PopupTips`, `BusyIndicator` | Feedback |
| `ActionTextField`, `TextField` | Text input with inline actions |
| `SegmentedControl` | Segmented buttons |
| `RoundedRect`, `RoundedRectangle` | Rounded rectangle (same thing, two names) |
| `ScrollBar` (`darkMode`), `Slider`, `Switch` | Fish-styled controls under FishUI names |
| `IconItem` | Theme or file icon: `source`, `color` |
| `WindowHelper`, `WindowBlur`, `WindowShadow` | The C++ helpers `Window` uses; also usable on other windows |
| `WheelHandler`, `SortFilterProxyModel`, `Dpi` | Utilities |

## Adding or changing a control

1. Put the QML in `src/controls/`.
2. List it in `src/fishui.qrc`.
3. Register it in `FishUI::registerTypes()` with `qmlRegisterType(componentUrl("X.qml"), uri, 1, 0, "X")`.
4. Add a line to `src/controls/qmldir`.

All four are needed: the plugin loads the qrc copy, while `qmllint` and tooling read the qmldir.

Watch out for these:
- **Imports:** inside FishUI use unversioned imports (`import QtQuick.Window`). A versioned `QtQuick.Window 2.3` hides newer properties such as `transientParent` (setback 32).
- **Aliases:** a root-level `property alias x: root.inheritedProperty` doesn't resolve. Use a plain property with a binding.
- **Error reporting:** QML stops at the first error, so one missing property hides the next. After a change, start every app that uses FishUI from a shell (Terminal is the most demanding one).
- **QML cache:** apps cache compiled QML in `~/.cache/<app>/qmlcache`. After installing a new FishUI, clear it when testing.

## Adding a live appearance setting

Follow `windowRadius`, which runs end to end:
1. **core:** `ThemeManager` property, setter, signal, D-Bus XML, key in `theme.conf`.
2. **cutefish-framework:** `Appearance` getter, setter and signal forwarding.
3. **fishui:** `ThemeManager` `Q_PROPERTY`, connected to `Appearance`; `Theme.qml` property.
4. **settings:** the UI that calls the setter.
5. **kwin-plugins / qt-plugins:** only if KWin or non-FishUI apps must follow too; they read `theme.conf` directly.
