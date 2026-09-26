# sddm-theme

`cutefish-sddm-theme`: the login screen, a QML theme for SDDM. Upstream is cutefishos/sddm-theme, ported to Qt 6.

## Files

| File | Installed to | What |
|---|---|---|
| `Main.qml` | `/usr/share/sddm/themes/cutefish/` | The whole screen: the default wallpaper, blurred; the clock; the user list; the password field; the session menu; the power buttons |
| `UserView.qml`, `SessionMenu.qml` | same | User avatar list, session picker |
| `theme.conf`, `metadata.desktop` | same | SDDM theme metadata |
| `sddm.conf` | `/etc/sddm.conf` | `[Theme] Current=cutefish`. It must end with a newline: casper appends `[Autologin]` to this file in the live session. |
| `hidpi.conf` | `/etc/sddm.conf.d/` | `EnableHiDPI=true` for Wayland and X11 |

## How it works

SDDM loads `Main.qml` with its context objects:
- `userModel` and `sessionModel`;
- `sddm`: `login(user, password, sessionIndex)`, `powerOff()`, `reboot()`, `suspend()`;
- `config` (from `theme.conf`).

The theme imports `SddmComponents 2.0` and **FishUI**, so the greeter needs `fishui` installed (a `Depends`).

The wallpaper is read from `/usr/share/backgrounds/cutefishos/default.jpg` (the `cutefish-wallpapers` package). It is sized with the window's device pixel ratio, so it stays sharp on HiDPI screens.

**The greeter's compositor isn't configured here.** `packaging/files/sddm/10-cutefish-wayland.conf` runs the greeter on `kwin_wayland` with the layer-shell integration, so the system needs no X server. The greeter's scale factor is written by core's `cutefish-sddm-helper` (`/etc/sddm.conf.d/scale.conf`).

## Testing

Run `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/cutefish` inside a session to try the theme without logging out. Otherwise, `sudo systemctl restart sddm`.
