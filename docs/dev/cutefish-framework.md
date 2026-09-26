# cutefish-framework

`libcutefish`: system-access libraries shared by the shell, Settings and the apps. Each area is a C++ library (`Cutefish::<Area>`) plus a QML module (`Cutefish.<Area>`). Upstream is cutefishos/cutefish-framework. We added the hotspot fixes and the `windowOpacity` / `windowRadius` appearance properties. API reference: [api/cutefish-framework.md](api/cutefish-framework.md).

## Modules

| Directory | QML import | C++ target | What it wraps | Main types |
|---|---|---|---|---|
| `appearance/` | `Cutefish.Appearance` | `Cutefish::Appearance` (shared, public header `Cutefish/appearance.h`) | core's `com.cutefish.Services` Appearance service | `Appearance`, `Wallpaper` |
| `applications/` | none (C++ only) | `Cutefish::Applications` (**static**) | core's `com.cutefish.AppRuntime`, `.desktop` files | `ApplicationRuntime`, `ApplicationLauncher`, `ApplicationRegistry`, `DesktopEntry` |
| `accounts/` | `Cutefish.Accounts` | `Cutefish::Accounts` | `org.freedesktop.Accounts` (AccountsService) | `AccountsManager`, `UserAccount`, `UsersModel` |
| `audio/` | `Cutefish.Audio` | `Cutefish::Audio` | PulseAudio / PipeWire-Pulse, libcanberra | `PulseAudio` (singleton: sinks, sources, streams, cards), `VolumeOSD`, `VolumeFeedback`, `SpeakerTest`, `MicrophoneIndicator`, `ListItemMenu`, `SortFilterModel` |
| `bluetooth/` | `Cutefish.Bluetooth` | `Cutefish::Bluetooth` | KF6 BluezQt | `Manager` (singleton), `BluetoothManager`, `BluetoothAgent` (pairing), device, adapter and battery wrappers |
| `media/` | `Cutefish.Media` | `Cutefish::Media` | MPRIS over D-Bus | `Mpris` (singleton), `MprisManager`, `MprisPlayer` |
| `network/` | `Cutefish.Network` | `Cutefish::Network` | KF6 NetworkManagerQt (ported from plasma-nm) | `NetworkModel`, `AppletProxyModel`, `Handler` (connect, disconnect, hotspot), `EnabledConnections`, `WifiSettings`, `Configuration`, `ActiveConnection` |
| `screen/` | `Cutefish.Screen` | `Cutefish::Screen` | KF6 Screen (libkscreen) | `Screen`, `Output`, `OutputModel` |

`cmake/CutefishFrameworkQml.cmake` holds the shared helper that turns each library into a QML module with `qt_add_qml_module`. All the modules are packaged in one `libcutefish` package. It depends on `libkscreen-bin`, because the kscreen backend runs as a helper process.

## How the pieces are used

- **`Appearance`** is how every UI process learns the look.
  - It watches for `com.cutefish.Services` on the session bus, then opens an interface to `/com/cutefish/Services/Appearance`.
  - It exposes the properties with change signals: `darkMode`, `accentColorIndex`, `blurEnabled`, `windowOpacity`, `windowRadius`, `fontFamily`, `fontPointSize`, wallpaper and background settings.
  - Setters are forwarded over D-Bus, and core stores the values in `~/.config/cutefishos/theme.conf`.
  - FishUI's `ThemeManager` is a thin layer over this class ([fishui.md](fishui.md)).
- **`Applications`** is compiled into its users. Settings, Files and Terminal build it from `../cutefish-framework/applications` (`add_subdirectory` in their CMakeLists), so in a build tree `cutefish-framework` must sit next to them. The Modal/Docker builder does that.
  - `ApplicationRuntime::instance()` calls core's AppRuntime (`launchApplication`, `launchCommand`, `quitApplication`, `isRunning`, `runningApplications`, `pidsForApplication`).
  - `ApplicationLauncher` wraps it for launching by desktop ID.
  - `ApplicationRegistry` indexes `.desktop` files.
  - Launching through AppRuntime keeps apps in the session's process tracking, and it's also how `scripts/vm.sh srun` starts things inside the session.
- **Network, Bluetooth, Audio and Screen** are used mainly by Settings pages and the status bar's Control Center. The QML types are models and handlers; the UI lives in those repos.

## Making changes

- **A new appearance property:** see the chain in [fishui.md](fishui.md#adding-a-live-appearance-setting). In `appearance/appearance.{h,cpp}`:
  - add the `Q_PROPERTY`, getter, setter and signal;
  - connect the D-Bus signal in `init()`: `connect(m_interface, SIGNAL(xChanged()), this, SIGNAL(xChanged()))`;
  - read the value through `m_interface->property("x")`.
- **A new QML type:** mark the class `QML_ELEMENT` (or `QML_NAMED_ELEMENT(Name)`) and add the files to that module's `CMakeLists.txt`. The module's `qt_add_qml_module` picks it up.
- **ABI:** `libcutefish` is a shared library used by other packages. When you change a public header (`/usr/include/Cutefish`), rebuild the users (shell, settings, filemanager) as well.
- **Hotspot:** `network/handler.cpp` (`createHotspot`, `stopHotspot`). Our fixes there are in `patches/cutefish-framework/`.
