# kwin-plugins

`cutefish-kwin-plugins`: everything Cutefish adds to KWin without patching it. It contains the window decoration, the rounded-corners effect, three script effects, the Alt+Tab switcher layout and the default `kwinrc` and shortcuts. Upstream is cutefishos/kwin-plugins. It depends on our KWin ([kwin-ubuntu.md](kwin-ubuntu.md)). API reference: [api/kwin-plugins.md](api/kwin-plugins.md).

## Layout

```
config/kwinrc             → /etc/xdg/kwinrc (system defaults; ~/.config/kwinrc overrides)
config/kglobalshortcutsrc → /etc/xdg/kglobalshortcutsrc (window and Space shortcuts)
plugins/decoration/       KDecoration3 plugin "org.cutefish.decoration" (C++)
plugins/roundedwindow/    KWin effect "cutefish_roundedwindow" (C++, OpenGL)
scripts/cutefishlauncher/ KWin script: keeps the launcher on the whole screen
scripts/cutefish_popups/  scripted effect: popup open/close animation (replaces fadingpopups)
scripts/cutefish_scale/   scripted effect: window open/close scale (replaces scale)
tabbox/cutefish_thumbnail/ Alt+Tab layout: grid of thumbnails (QML)
```

Install paths:
- the decoration goes to `qt6/plugins/org.kde.kdecoration3/`;
- the effect goes to `qt6/plugins/kwin/effects/plugins/`;
- the scripts and tabbox go to `/usr/share/kwin/{scripts,effects,tabbox}`.

## Build

`find_package(KDecoration3 REQUIRED)` and `find_package(KWin REQUIRED)`. The KWin headers come from our `kwin-dev` (6.6.6+cutefish). `KWinConfig.cmake` also needs `libdrm-dev`, epoxy, Wayland and several KF6 packages, all in `Build-Depends`.

Both lookups used to be `QUIET`, and a missing dependency silently produced a package without the effect (setback 33). Both are now `REQUIRED`. In addition, `scripts/build-in-container.sh` refuses a kwin-plugins package that lacks either `cutefish_roundedwindow.so` or `org.cutefish.decoration.so`.

The effect compiles against KWin's **internal** C++ API (`effect/`, `opengl/`, `core/` headers). That API changes between KWin releases; 6.6, for instance, folded `OpenGlContext` into `EglContext`. After bumping KWin, rebuild this package and expect small fixes.

## Window corners: how the radius flows

```
Settings → Appearance → Window corners
  └─ com.cutefish.Services …/Appearance setWindowRadius(int)     (core)
       └─ ~/.config/cutefishos/theme.conf  WindowRadius=0…24
            ├─ FishUI Theme.windowRadius  (live, over D-Bus)          FishUI windows
            ├─ decoration: QFileSystemWatcher → reloadTheme()        title bar + shadow
            └─ roundedwindow: QFileSystemWatcher → reloadRadius()    everything else
```

The decoration and the effect read the file themselves, so no D-Bus call to KWin is needed. `QSettings` replaces the file when it writes, which drops an inotify watch, so both re-add the path after each change. A radius of 0 turns rounding off.

## Decoration (`plugins/decoration`)

`Decoration : KDecoration3::Decoration` and `Button : KDecoration3::DecorationButton`.

- **Title bar:** a solid colour, light or dark following `DarkMode` in `theme.conf`, with a centred caption. The buttons are SVGs from `resources.qrc`, rendered per scale, and `ButtonsOnRight=HIAX` in `kwinrc` sets their order.
- **Shadow:** drawn once into a shared cache, one for active and one for inactive windows, rebuilt when the radius changes. Its inner cut-out is a rounded rectangle, so the shadow follows the corner radius.
- **Selection:** `kwinrc [org.kde.kdecoration2] library=org.cutefish.decoration`. KWin 6 still reads the old group name.

Which windows get it: every window that asks for a server-side decoration. FishUI apps draw their own frame (client-side), so they don't. Firefox gets it with `browser.tabs.inTitlebar=0`.

## Rounded-corners effect (`plugins/roundedwindow`)

`RoundedWindow : KWin::OffscreenEffect`. It renders each chosen window into an offscreen texture, then draws it through a fragment shader. The shader:
- cuts the four corners to `radius × scale`;
- rebuilds the window's shadow in the cut-out, so the corners don't look clipped;
- applies KWin's opacity and saturation modulation last, so fades and "dim inactive" still work.

`shouldRound(window)` decides which windows qualify. It is **false** for:
- unmanaged windows, or any window when the radius is 0;
- fullscreen or maximized windows (except while animating out of maximize);
- desktops, docks, menus, popups, tooltips, notifications, on-screen displays, drag icons and splash screens;
- windows without a server-side decoration, unless their class is in `s_allowList`. That list holds apps that draw their own frame but should still be rounded (VS Code, DingTalk, …).

Otherwise it is true for normal windows, dialogs and utilities.

Maximize and restore are tracked (`m_maximizingWindows`, `m_restoringWindows`), so a window doesn't flash square or reuse a full-screen texture. Closed windows keep their rounded texture until their close animation finishes (`m_closingWindows`).

To add an app that draws its own frame, add its `windowClass` ("resource-name resource-class", as KWin reports it) to `s_allowList`.

## Scripts

- **`cutefishlauncher`** (a KWin script): forces the launcher's window onto the whole screen area, because the dock and status bar reserve work area and KWin would otherwise shrink it. It stays a normal window so the dock floats above it.
- **`cutefish_popups`** and **`cutefish_scale`** (scripted effects, JavaScript): open and close animations. They replace KWin's `fadingpopups` and `scale`, which `kwinrc` turns off. `cutefish_scale` skips `cutefish-shell` windows.

## `config/kwinrc` highlights

| Group / key | Why |
|---|---|
| `[Plugins]` | Enables `blur`, `cutefish_*`, `fadedesktop`, `overview` and `magiclamp`. Disables `slide`, which isn't per-output aware ([../multi-display.md](../multi-display.md)), and KWin's own fade and scale. |
| `[Effect-blur] BlurStrength, NoiseStrength, ForceBlurClasses` | Blur defaults. `ForceBlurClasses` is our KWin patch for per-app blur ([../blur.md](../blur.md)). The group name is case-sensitive. |
| `[Windows] PerOutputVirtualDesktops=true` | Separate Spaces per display (our KWin backport) |
| `[TabBox] LayoutName=cutefish_thumbnail` | Alt+Tab layout |
| `[org.kde.kdecoration2]` | Decoration plugin and button order |

Users change most of these through Settings (Blur & Transparency, Appearance). Settings writes `~/.config/kwinrc` and calls `org.kde.KWin /Effects reconfigureEffect` or `org.kde.KWin /KWin reconfigure`.

## Checking it in a session

```sh
busctl --user get-property org.kde.KWin /Effects org.kde.kwin.Effects loadedEffects   # expect cutefish_roundedwindow
busctl --user call com.cutefish.Services /com/cutefish/Services/Appearance \
    com.cutefish.Services.Appearance setWindowRadius i 24                             # corners change live
```
