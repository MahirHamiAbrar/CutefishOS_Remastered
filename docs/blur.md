# macOS-style window blur

Blur is **on by default**, and it can be switched off in Settings → Appearance → *Enable blur*.

## What gets blurred

| Surface | How |
|---|---|
| Status bar, dock, launcher, menus, popups, notifications | Upstream Cutefish already asks KWin for blur behind them (`FishUI.WindowBlur`) |
| **Every FishUI app window** (Files, Terminal, Settings, Calculator, Text Editor, Screenshot, Network Monitor prompt) | New: `FishUI.Window` gets a `blurBehind` property (default = the Appearance blur switch). It turns on `WindowBlur` for the window's rounded shape and makes the window background translucent: 82 % opaque in light mode, 78 % in dark. Opaque content (file view, text) stays opaque, so only sidebars, headers and empty areas show the frosted desktop, like macOS vibrancy. |
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

Blur behind an opaque window is invisible, so Settings also writes a normal KWin window rule for each chosen app: `~/.config/kwinrulesrc`, rule id `cutefish-blur-<class>`, opacity 90 % active and 85 % inactive. Your own window rules are left alone. After every change Settings calls `org.kde.KWin.reconfigure` and `reconfigureEffect("blur")`, so nothing needs a restart.

The *Strength* slider writes `[Effect-blur] BlurStrength` (1–15).

## Files

- `src/fishui/src/controls/Window.qml`: default blur and translucency
- `src/settings/src/windoweffects.{h,cpp}`: settings backend (kwinrc, kwinrulesrc, D-Bus reconfigure)
- `src/settings/src/qml/Appearance/Main.qml`: UI
- `src/kwin-ubuntu/src/plugins/blur/blur.{cpp,h,kcfg}`: `ForceBlurClasses`
- `src/kwin-plugins/config/kwinrc`: `[Effect-blur]` defaults. The group name was wrong upstream (`Effect-Blur`), see setback 5.

## Performance

KWin's dual-Kawase blur is cheap on any GPU with OpenGL ES 3 / OpenGL 3. In a VM without 3D acceleration KWin falls back to llvmpipe, and blur on large windows becomes noticeably slow there. Switch blur off in that case.
