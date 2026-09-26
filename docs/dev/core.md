# core

`cutefish-core`: the session and the system services behind the desktop. It contains:
- the session manager (`cutefish-session`) and the Wayland session scripts;
- the settings daemon (`cutefish-services`);
- the application runtime (`cutefish-appruntime`);
- the polkit authentication agent;
- small privileged helpers.

Upstream is cutefishos/core. Our changes:
- the session script exports `XDG_MENU_PREFIX`, `GTK_MODULES` and `PLASMA_DEFAULT_SHELL`;
- the display language and the formats locale are applied separately;
- the default fonts are Inter and JetBrains Mono;
- the Appearance service has `windowOpacity` and `windowRadius`.

API reference, with every D-Bus interface: [api/core.md](api/core.md).

## Layout

```
session/             cutefish-session: environment, language, starts everything, logout/reboot
  cutefish-wayland.desktop         the SDDM session entry
  cutefish-wayland-session         exports env, execs kwin_wayland_wrapper --xwayland
  cutefish-kwin-wayland-session    run by KWin: execs cutefish-session
  cutefish-applications.menu       XDG menu (KService needs it; see the script's comment)
  application.*                    environment, initLanguage(), D-Bus com.cutefish.Session
  processmanager.*                 start order, XDG autostart, stopping on logout
  powermanager/, networkproxymanager.*
cutefish-services/   cutefish-services: settings daemon, D-Bus com.cutefish.Services
  appearance/        /com/cutefish/Services/Appearance   theme.conf, fonts, dark mode, blur, opacity, radius, wallpaper
  locale/            /com/cutefish/Services/Language     display language
  power/             /com/cutefish/Services/Power        idle, dim, sleep, CPU governor
  battery/           /com/cutefish/Services/Battery      UPower
  brightness/        /com/cutefish/Services/Brightness   backlight (through the pkexec helper)
  input/             /com/cutefish/Services/Input/{Mouse,Touchpad}   through KWin's InputDevice D-Bus API
  clipboard/         clipboard persistence (wlr-data-control)
appruntime/          cutefish-appruntime: D-Bus com.cutefish.AppRuntime /AppRuntime
polkit-agent/        cutefish-polkit-agent: password dialog (QML) for polkit
screen-brightness/, cpufreq/, sddm-helper/   pkexec helpers with polkit policies
```

It also builds `../cutefish-framework/applications`, the static `Cutefish::Applications` library, which needs the sibling checkout.

## Startup sequence

1. SDDM starts `cutefish-wayland-session`. It exports `XDG_MENU_PREFIX=cutefish-`, `XDG_CURRENT_DESKTOP=Cutefish`, `GTK_MODULES=…appmenu-gtk-module` and `PLASMA_DEFAULT_SHELL`, then execs `kwin_wayland_wrapper --xwayland`, which runs `cutefish-kwin-wayland-session`, which runs `cutefish-session`.
2. `cutefish-session` (`Application`):
   1. creates `~/.config`;
   2. runs **`initLanguage()`**;
   3. sets the rest of the environment (`QT_QPA_PLATFORM=wayland;xcb`, `QT_QPA_PLATFORMTHEME=cutefish`, the GTK button layout);
   4. pushes the environment to D-Bus and systemd (`dbus-update-activation-environment --systemd --all`);
   5. imports systemd's user environment.
3. **`ProcessManager::start()`** waits for `org.kde.KWinWrapper`. It then:
   1. starts the daemons (`cutefish-appruntime`, `cutefish-services`);
   2. waits for `com.cutefish.Services`;
   3. starts `cutefish-shell` (status bar, dock, launcher, desktop, notifications: one process);
   4. starts `cutefish-welcome` (installed systems only);
   5. runs **XDG autostart** entries (`/etc/xdg/autostart`, `~/.config/autostart`; a user entry with the same name replaces the system one, and `Hidden` or `OnlyShowIn`/`NotShowIn`/`TryExec` are honoured).

### Language and formats (`initLanguage`)

It reads `~/.config/cutefishos/language.conf`:

| Setting | Where it comes from | What it sets |
|---|---|---|
| **Display language:** the `language` key | `LANG` from `/etc/default/locale` (the installer's choice), then the last uncommented line of `/etc/locale.gen`, then `en_US` | `LANG` and `LANGUAGE`; `LC_*` only where the system hasn't set them |
| **Formats:** the `formats` key (Settings → Region & Language) | the user | `LC_NUMERIC`, `LC_TIME`, `LC_MONETARY`, `LC_MEASUREMENT`, `LC_PAPER`, overriding both |

The time zone never takes part.

## The settings daemon (`cutefish-services`)

One process, one bus name (`com.cutefish.Services`), one object per area. Each area is a `QObject` with a D-Bus adaptor generated from its XML file. The adaptors are listed in `cutefish-services/CMakeLists.txt`.

**Appearance (`ThemeManager`)** stores everything in `~/.config/cutefishos/theme.conf`:
- keys `DarkMode`, `AccentColor`, `Font`, `FixedFont`, `FontSize`, `IconTheme`, `CursorTheme`, `CursorSize`, `Wallpaper`, `BackgroundType`, `BackgroundColor`, `DarkModeDimsWallpaer` (sic), `BlurEnabled`, `WindowOpacity` (0.4–1, default 0.7) and `WindowRadius` (0–24, default 14);
- each setter clamps its value, writes, `sync()`s and emits a change signal;
- the first-run fonts are Inter and JetBrains Mono, with Noto Sans CJK for Chinese and Japanese;
- changes that KDE and KF6 apps should notice are announced with the `org.kde.KGlobalSettings` `notifyChange` signal.

Readers of `theme.conf`:
- over D-Bus: the framework's `Appearance`, then FishUI and the shell;
- directly from the file: qt-plugins, and the KWin decoration and rounded-corners effect.

## Application runtime (`cutefish-appruntime`)

`com.cutefish.AppRuntime /AppRuntime`:
- methods `launchApplication(appId, args)`, `launchCommand(appId, argv, workingDir)`, `quitApplication(appId)`, `quitAll()`, `quitByPid(pid)`, `isRunning(appId)`, `runningApplications()` and `pidsForApplication(appId)`;
- signals `applicationLaunched` and `applicationQuit`.

It starts programs detached with the session's environment and tracks their PIDs per app ID. The dock and launcher use it through the framework's `ApplicationLauncher`. Because it runs inside the logind session, things started through it are "active" for polkit; `scripts/vm.sh srun` relies on that.

## Session D-Bus (`com.cutefish.Session /Session`)

Methods: `logout()`, `reboot()`, `powerOff()`, `suspend()`, `startDesktopProcess()` and `updateNetworkProxy()`.

## Privileged helpers

Each helper is a tiny program run through `pkexec` and covered by a polkit policy (`*.pkexec.policy.in`):

| Helper | Does | Used by |
|---|---|---|
| `cutefish-screen-brightness` | Writes `/sys/class/backlight/*/brightness` | Brightness service |
| `cutefish-cpufreq` | Writes `scaling_governor` for a CPU | Power service |
| `cutefish-sddm-helper` | Writes `/etc/sddm.conf.d/scale.conf` (greeter scale factor) | Settings |

## Making changes

- **A new appearance setting:** add it to `appearance/thememanager.{h,cpp}` (property, setter with clamp, signal, `theme.conf` key) and to `appearance/com.cutefish.Appearance.xml`. Then continue in the framework and FishUI ([fishui.md](fishui.md#adding-a-live-appearance-setting)).
- **Something the session must start:** add it to `startDaemonProcess()` or `startDesktopProcess()`. For anything optional, prefer an XDG autostart file in `packaging/`.
- **Environment for the whole session:** use `session/cutefish-wayland-session` if KWin itself needs it, otherwise `Application::initEnvironments()`.
- **Testing a change to the session:** install, then `sudo systemctl restart sddm` and log in again. `cutefish-services` alone can be swapped without a new session: `pkill -x cutefish-services`, then start it from a session shell. The session doesn't restart it on its own.
