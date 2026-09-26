# settings

`cutefish-settings`: the System Settings application. It is a sidebar of pages, each a QML file backed by small C++ classes or by the framework's QML modules. Upstream is cutefishos/settings.

Our additions:
- the **Blur & Transparency** page;
- **Window corners** (on Appearance);
- **Region & Language**: formats and keyboard layouts;
- manual **date and time**, and a **time-zone search**;
- the **Network Monitor** page;
- the **Hotspot** page, restored;
- the "separate Spaces" switch;
- per-app blur.

API reference: [api/settings.md](api/settings.md).

## Layout

```
src/main.cpp, application.*   QApplication; -m <module> opens a page; single instance via
                              D-Bus com.cutefish.SettingsUI /SettingsUI switchToPage(name)
src/qml/main.qml              FishUI.Window: SideBar + StackView
src/qml/SideBar.qml           ListModel of pages: title, name, page (qrc URL), icon, category
src/qml/<Page>/Main.qml       one directory per page (LanguagePage.qml is the exception)
src/qml/{ItemPage,RoundedItem,StandardItem,StandardButton,IconButton,…}.qml   shared page building blocks
src/*.{h,cpp}                 backends, registered as "Cutefish.Settings 1.0" in application.cpp
src/datetime/, time/          Time (timedated), TimeZoneMap, TimeZoneModel
src/cursor/, fonts/, update/, vpn/
src/resources.qrc             every QML file and image (the QML is compiled into the binary)
```

`CMakeLists.txt` also builds `../cutefish-framework/applications` (static), so the framework checkout must sit next to it.

## Pages and their backends

| Sidebar entry | QML | Backend |
|---|---|---|
| WLAN, Ethernet, Hotspot | `WLAN/`, `Wired/`, `Hotspot/` | `Cutefish.Network` (framework) |
| Network Monitor | `NetMonitor/` | `NetMonitorClient`: D-Bus to `com.cutefish.NetMonitor` ([../privacy-netmonitor.md](../privacy-netmonitor.md)) |
| Bluetooth | `Bluetooth/` | `Cutefish.Bluetooth` |
| Proxy | `Proxy/` | `NetworkProxy`; core's session applies it |
| Display | `Display/` | `Cutefish.Screen`, `Brightness`; `WindowEffects.separateSpaces` |
| Appearance | `Appearance/` | `Cutefish.Appearance` (dark mode, accent, fonts, **window corners**), `Fonts`, `FontsModel` |
| Blur & Transparency | `Blur/` | `Cutefish.Appearance` (`blurEnabled`, `windowOpacity`), `WindowEffects` |
| Background | `Wallpaper/` | `Cutefish.Appearance` `Wallpaper` |
| Dock | `Dock/` | `DockSettings`: D-Bus to the shell's dock |
| User | `User/` | `Cutefish.Accounts`, `Password` |
| Notifications | `Notification/` | `Notifications`: D-Bus to the shell |
| Sound | `Sound/` | `Cutefish.Audio` |
| Mouse, Touchpad | `Cursor/`, `Touchpad/` | `Mouse`, `CursorThemeModel`, `Touchpad`: core's Input services |
| Date & Time | `DateTime/` | `Time`, `TimeZoneMap` |
| Default Applications | `DefaultApp/` | `DefaultApplications` (`~/.config/mimeapps.list`) |
| Region & Language | `LanguagePage.qml` | `Language`, `KeyboardLayouts` |
| Battery, Power | `Battery/`, `Power/` | `Battery`, `BatteryHistoryModel`, `PowerManager` |
| About | `About/` | `About` |

`VPN/`, `Application/` and `Update/` exist, but their sidebar entries are commented out.

## The newer backends in detail

**`WindowEffects`** (Blur & Transparency, Display) edits `~/.config/kwinrc` and `kwinrulesrc` with `KConfig`, then tells KWin over `org.kde.KWin /Effects`:

| Property / method | Config | KWin call |
|---|---|---|
| `blurStrength` 1–15, `noiseStrength` 0–14 | `[Effect-blur]` | `reconfigureEffect("blur")` |
| `forcedApps`, `addForcedApp(class)`, `removeForcedApp(class)`, `availableApps` | `[Effect-blur] ForceBlurClasses`, plus a `kwinrulesrc` opacity rule per app | `reconfigureEffect("blur")`, rules reload |
| `forcedActiveOpacity`, `forcedInactiveOpacity` | the opacity in those rules | rules reload |
| `translucencyEnabled`, `inactiveOpacity`, `moveResizeOpacity` | `[Plugins] translucencyEnabled`, `[Effect-translucency]` | `loadEffect`/`unloadEffect`, `reconfigureEffect("translucency")` |
| `separateSpaces` | `[Windows] PerOutputVirtualDesktops` | KWin reconfigure |
| `resetDefaults()` | all of the above | all of the above |

The system-wide blur switch and the window opacity aren't KWin settings. They live in core's Appearance service, and the page calls them through `Cutefish.Appearance`.

**Window corners** (Appearance): preset tiles (Square 0, Small 6, Medium 10, Default 14, Large 20) and a slider call `Appearance.setWindowRadius`. Everything follows live ([kwin-plugins.md](kwin-plugins.md#window-corners-how-the-radius-flows)).

**`Language`** (Region & Language):
- **Display language:**
  - `languages` and `currentLanguage`;
  - `setCurrentLanguage(i)` writes `language` to `~/.config/cutefishos/language.conf`.
- **Formats:**
  - `formats`, `currentFormats` and `formatsPreview` (a sample number, date and currency);
  - `setCurrentFormats(i)` runs `pkexec /usr/sbin/locale-gen <code>.UTF-8` when that locale isn't generated yet (`formatsBusy` is true meanwhile), then writes `formats`.
- Both take effect at the next login; core's session applies them ([core.md](core.md#language-and-formats-initlanguage)).

**`KeyboardLayouts`**:
- `availableLayouts` and `variants(layout)` are parsed from `/usr/share/X11/xkb/rules/evdev.xml`;
- `layouts`, `addLayout`, `removeLayout` and `moveLayout` edit `~/.config/kxkbrc [Layout]` (`LayoutList`, `VariantList`, `Use=true`);
- `switchShortcut` writes `Options=grp:…`, default Meta+Space;
- each change emits the `org.kde.keyboard /Layouts reloadConfig` signal, and KWin applies it immediately.

**`Time`** and **`TimeZoneMap`** (Date & Time):
- `useNtp` + `save()` call timedated `SetNTP`;
- `setDateTime(date, time)` calls `SetTime`, and is only possible with NTP off;
- `TimeZoneMap.search(text)` returns matching cities (city, country, zone), `select(zone)` sets it, and `clicked(x, y, w, h)` picks from the map.
- None of it touches the language or the formats.

## Adding a page

1. Create `src/qml/<Name>/Main.qml`, starting from `ItemPage` with `Scrollable` and `RoundedItem` sections, like the other pages.
2. Add it to `resources.qrc`.
3. Add a `ListElement` in `SideBar.qml` with `title`, `name` (the `-m` module name), `page`, `iconSource` (an SVG in `images/`) and `category`.
4. For a backend: create a `QObject` in `src/`, add it to `CMakeLists.txt`, and call `qmlRegisterType` in `application.cpp`.
5. Changes that other processes must see go through their D-Bus service (core, shell, KWin), never by writing another program's state directly, except KWin's own config files as `WindowEffects` does.

To test, start `cutefish-settings -m <name>`, and remember that stale QML caches hide changes.
