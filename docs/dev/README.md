# Developer guides

One guide per repository under `src/`: what it is, how it is built, how its parts fit together and where to make a change. Each code repository also has a generated API reference in [api/](api/). It lists every Qt property, invokable, slot and signal, every D-Bus interface, and the properties of every exported QML type.

Start with [../architecture.md](../architecture.md) for the whole system, and [../building.md](../building.md) for the build machinery.

## The repositories

| Guide | What it is | API |
|---|---|---|
| [fishui.md](fishui.md) | UI toolkit: `FishUI` QML module (Window, Theme, controls) and the `Fish` Qt Quick Controls style | [api](api/fishui.md) |
| [cutefish-framework.md](cutefish-framework.md) | `libcutefish`: QML modules for accounts, appearance, audio, Bluetooth, MPRIS, network, screens; app launching | [api](api/cutefish-framework.md) |
| [core.md](core.md) | Session manager, settings daemon (`cutefish-services`), polkit agent, app runtime, helpers | [api](api/core.md) |
| [shell.md](shell.md) | Status bar (one per display), dock, launcher, desktop surfaces, notification server | [api](api/shell.md) |
| [settings.md](settings.md) | System Settings application | [api](api/settings.md) |
| [filemanager.md](filemanager.md) | Files, and the desktop (icons and wallpaper) | [api](api/filemanager.md) |
| [terminal.md](terminal.md) | Terminal, with its QML terminal widget (`Cutefish.TermWidget`) | [api](api/terminal.md) |
| [calculator.md](calculator.md) | Calculator | [api](api/calculator.md) |
| [texteditor.md](texteditor.md) | Text Editor | [api](api/texteditor.md) |
| [screenshot.md](screenshot.md) | Screenshot tool | [api](api/screenshot.md) |
| [qt-plugins.md](qt-plugins.md) | Qt platform theme (`cutefish`), `cutefishstyle` widget style, SVG image plugin | [api](api/qt-plugins.md) |
| [kwin-plugins.md](kwin-plugins.md) | Window decoration, rounded-corners effect, KWin scripts and default `kwinrc` | [api](api/kwin-plugins.md) |
| [kwin-ubuntu.md](kwin-ubuntu.md) | Our KWin: Ubuntu's source plus per-output desktops and forced blur | [api](api/kwin-ubuntu.md) |
| [calamares-ubuntu.md](calamares-ubuntu.md) | Our Calamares: Ubuntu's source plus the locale patch | none |
| [cutefish-calamares-settings.md](cutefish-calamares-settings.md) | Old upstream installer branding (superseded by `packaging/calamares`) | none |
| [sddm-theme.md](sddm-theme.md) | Login screen | none |
| [icons.md](icons.md) | `Cutefish`, `Cutefish-Light` and `Cutefish-Dark` icon themes (Colloid-based) | none |
| [gtk-themes.md](gtk-themes.md) | GTK 2/3/4 themes matching FishUI | none |
| [cursor-themes.md](cursor-themes.md) | Cursor theme | none |
| [plymouth-theme.md](plymouth-theme.md) | Boot splash | none |
| [wallpapers.md](wallpapers.md) | Default wallpapers | none |

Two directories live in this repository itself rather than under `src/`: `netmonitor/` ([../privacy-netmonitor.md](../privacy-netmonitor.md)) and `packaging/` ([../building.md](../building.md)).

## How the pieces talk to each other

```
                 ┌──────────────── cutefish-services (core) ─────────────────┐
                 │ com.cutefish.Services: /com/cutefish/Services/Appearance… │
                 │ writes ~/.config/cutefishos/*.conf                        │
                 └──────────────▲────────────────────────▲───────────────────┘
                         D-Bus  │                        │ D-Bus
   ┌────────────────────────────┴───┐          ┌─────────┴───────────────┐
   │ cutefish-framework              │          │ settings (writes)       │
   │  Appearance ◄─ FishUI ThemeManager │       │ shell (reads, listens)  │
   └──────────────▲──────────────────┘          └─────────────────────────┘
                  │ QML: FishUI.Theme.*
   every app: filemanager, terminal, calculator, texteditor, screenshot, settings, shell
```

- **Look and feel** come from core's settings daemon. The framework's `Appearance` class mirrors it over D-Bus, and FishUI's `ThemeManager` exposes it to QML as `FishUI.Theme`. A change in Settings reaches every open window live.
- **Window effects** (blur, rounding, decoration) belong to KWin. Apps ask for them through FishUI (`WindowBlur`, `WindowHelper`), which uses KWindowSystem. The system-wide switches live in `~/.config/kwinrc`, which Settings writes before telling KWin to reconfigure.
- **App launching** goes through `cutefish-appruntime` (core, `com.cutefish.AppRuntime`), which the framework's `Cutefish::Applications` library wraps.

## Working on a repository

`src/` is not in git. Each `src/<repo>` is an upstream checkout on a branch named `remastered`: the commit pinned in `repos.lock` plus our patches from `patches/<repo>/`. The patches are the source of truth. If `src/` is lost or stale, `scripts/fetch.sh` recreates it.

1. **Edit** in `src/<repo>`.
2. **Commit and export** with `source scripts/lib-commit.sh`, then run `commit_pkg <repo> "<what changed>"`. This adds a `+remasteredN` changelog entry, commits, and rewrites `patches/<repo>/`. For a follow-up fix to the last change, use `amend_pkg <repo>`, which doesn't bump the version.
3. **Build** on Modal: `MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py --pkgs "<repo> …"`. Locally, use `scripts/build-debs.sh <repo>`. Debs land in `build/repo/` and logs in `build/logs/<repo>.log`.
   - Don't edit `src/`, `packaging/` or `scripts/` until `>>>` appears in the Modal output; the sources are uploaded at the start.
   - A Modal run syncs its output only when it ends, so don't kill it.
4. **Commit** `patches/` (never `src/`) in this repository and push.
5. **Test** in the VM:
   - copy the debs in, then run `sudo apt install ./…deb`;
   - delete stale QML caches with `rm -rf ~/.cache/*/qmlcache`;
   - restart the app, or `sudo systemctl restart sddm` for session parts;
   - start every app you touched from a shell and read what it prints. A QML error there means the app never opens (setback 31).

   See [../testing.md](../testing.md).
6. **Refresh the API reference** after changing interfaces: `scripts/gen-dev-api.py <repo>`.

The KWin and Calamares forks are not upstream git checkouts, and `commit_pkg` doesn't work for them. See their guides.

## Conventions shared by the apps

- **Qt 6, QML first.** C++ holds models and system access. Everything visible is QML, compiled into the binary through `qml.qrc` or `qt_add_qml_module`.
- **UI:** apps import `FishUI 1.0` and use `FishUI.Window` as the root window. It draws the translucent, blurred background, the header and the window buttons. Colours, spacing and radii come from `FishUI.Theme` and `FishUI.Units`, never hard-coded.
- **Settings files:** `~/.config/cutefishos/<name>.conf` (QSettings INI). Apps with their own settings use `~/.config/<app>/`.
- **Translations:** `translations/*.ts`, compiled to `/usr/share/<app>/translations/<locale>.qm` and loaded in `main.cpp` from `QLocale().name()`.
- **Packaging:** each repo has its own `debian/`, built with `dpkg-buildpackage -b`. Runtime QML modules must be listed in `Depends` (for example `qml6-module-qtquick-layouts`), because a missing one surfaces only as a QML error at startup.
