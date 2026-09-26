# macOS-style window blur

Blur is **on by default**. Everything about it is on its own Settings page, **Blur & Transparency** (next to Appearance):

| Control | Stored in | Default |
|---|---|---|
| Blur behind windows, panels and menus | `~/.config/cutefishos/theme.conf` `BlurEnabled` (Appearance service) | on |
| Window opacity (FishUI apps) | `theme.conf` `WindowOpacity`, 0.4–1.0 (Appearance service → `FishUI.Theme.windowOpacity`) | 0.70 (dark mode 0.04 lower) |
| Blur strength | `kwinrc` `[Effect-blur] BlurStrength`, 1–15 | 15 |
| Noise strength | `kwinrc` `[Effect-blur] NoiseStrength`, 0–14 | 0 |
| Always blur these apps | `kwinrc` `[Effect-blur] ForceBlurClasses` + window rules | none |
| Their opacity, active / inactive | `kwinrc` `[Cutefish] ForcedAppActiveOpacity` / `ForcedAppInactiveOpacity` → the window rules | 90 % / 85 % |
| KWin Translucency effect (all windows) | `kwinrc` `[Plugins] translucencyEnabled`, `[Effect-translucency] Inactive`, `MoveResize` | off, 85 %, 80 % |
| Reset to defaults | all of the above | |

The window opacity changes open FishUI windows live. The sidebars of Files and Settings add only a light tint (30 %) on top, so they stay frosted and follow the setting. Before, a 70 % tint over an 82 % window made them about 95 % opaque.

Settings → Appearance → **Window corners** sets `theme.conf` `WindowRadius` (0–24 px, default 14). FishUI windows follow it live, and so do KWin's Cutefish decoration and the rounded-corners effect, which both watch `theme.conf`. Menus and popups keep their own radius.

## What gets blurred

| Surface | How |
|---|---|
| Status bar, dock, launcher, menus, popups, notifications | Upstream Cutefish already asks KWin for blur behind them (`FishUI.WindowBlur`) |
| **Every FishUI app window** (Files, Terminal, Settings, Calculator, Text Editor, Screenshot, Network Monitor prompt) | New: `FishUI.Window` gets a `blurBehind` property (default = the Appearance blur switch). It turns on `WindowBlur` for the window's rounded shape and makes the window background translucent at the *Window opacity* setting. Opaque content (file view, text) stays opaque, so only sidebars, headers and empty areas show the frosted desktop, like macOS vibrancy. |
| **Third-party apps you choose** | New: Settings → Appearance → Blur → *Always blur these apps* |

An app can opt out with `blurBehind: false` or by setting `background.opacity`. Terminal keeps its own opacity setting (85 % by default) and is now blurred behind it.

## Per-app blur for any application

Apps that never ask for blur (Firefox, LibreOffice, GTK apps…) can't be blurred from outside with stock KWin 6.6. The blur region comes only from the client, and `WindowForceBlurRole` only keeps an existing blur alive during full-screen effects (see setback 6). Since we already ship our own KWin build, the blur effect got one option:

```ini
# ~/.config/kwinrc
[Effect-blur]
ForceBlurClasses=firefox,org.kde.kate
```

A window whose resource name or class matches (case-insensitive) is blurred behind as a whole (`patches/kwin/cutefish-blur-0001-force-blur-classes.patch`). Its blur is drawn at full strength whatever the window's opacity; only open/close animations fade it (`cutefish-blur-0002`, see setbacks §23).

Blur behind an opaque window is invisible, so Settings also writes a normal KWin window rule for each chosen app: `~/.config/kwinrulesrc`, rule id `cutefish-blur-<class>`, with the page's active and inactive opacity (90 % and 85 % by default). Your own window rules are left alone. After every change Settings calls `org.kde.KWin.reconfigure` and `reconfigureEffect("blur")`, so nothing needs a restart.


## Files

- `src/fishui/src/controls/Window.qml`: default blur and translucency
- `src/settings/src/windoweffects.{h,cpp}`: settings backend (kwinrc, kwinrulesrc, D-Bus reconfigure)
- `src/settings/src/qml/Blur/Main.qml`: the Blur & Transparency page; `Appearance/Main.qml`: Window corners
- `src/core/cutefish-services/appearance/thememanager.{h,cpp}`, `src/cutefish-framework/appearance/`, `src/fishui/src/thememanager.{h,cpp}`: `windowOpacity`, `windowRadius`
- `src/kwin-plugins/plugins/{decoration,roundedwindow}`: follow `WindowRadius`
- `src/kwin-ubuntu/src/plugins/blur/blur.{cpp,h,kcfg}`: `ForceBlurClasses`
- `src/kwin-plugins/config/kwinrc`: `[Effect-blur]` defaults. The group name was wrong upstream (`Effect-Blur`), see setback 5.

## Performance

KWin's dual-Kawase blur is cheap on any GPU with OpenGL ES 3 / OpenGL 3. In a VM without 3D acceleration KWin falls back to llvmpipe, and blur on large windows becomes noticeably slow there. Switch blur off in that case.
