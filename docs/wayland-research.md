# X11 or Wayland?

**Short answer:** Stay on Wayland. We don't have to migrate anything, because upstream Cutefish already moved to Wayland in 2026. Bringing X11 back would add bugs.

## What the code base actually is

The 2021–2023 Cutefish that most people remember ran on X11 with Qt 5. The `cutefishos-ubuntu` forks linked in the brief are copies of that code. Nobody touched them after 2023.

In August–September 2026 the original author revived [github.com/cutefishos](https://github.com/cutefishos) (about 250 commits in five weeks):

| Area | Old Cutefish (≤2023) | Revived upstream (2026) |
|---|---|---|
| Toolkit | Qt 5.15, KF5 | Qt 6.10, KF6, C++20 |
| Display server | X11 (KWin X11) | Wayland only (KWin Wayland); X11 apps run in XWayland |
| Shell | separate `dock`, `statusbar`, `launcher` processes | one `cutefish-shell` process, one QML engine |
| Window list and task management | X11 atoms (`_NET_*`) | `org_kde_plasma_window_management` |
| Panels | X11 struts, `_NET_WM_WINDOW_TYPE_DOCK` | `org_kde_plasma_shell` + layer-shell, a "strut spacer" |
| Screen locker | own `cutefish-screenlocker` | KWin's kscreenlocker |
| Clipboard manager | X11 selections | Wayland data-control protocol |
| Global menu | `_KDE_NET_WM_APPMENU_*` X properties | KWin app-menu info + `com.canonical.AppMenu.Registrar`, matched by PID |
| CI | none / Ubuntu 21.04 | Debian sid and **Ubuntu 26.04** |

The session file `cutefish-wayland.desktop` starts `kwin_wayland_wrapper --xwayland`. There is no X11 session any more.

## Would moving to Wayland be trouble?

We no longer have to move: upstream has done it. The real question is whether to *add an X11 session back*. We did not, for these reasons:

1. **Two code paths, double the bugs.** Upstream deleted the X11 integration: struts, `_NET_*` window tracking, the X11 screen locker, X11 screenshots. Restoring it means maintaining code that nobody upstream tests.
2. **Per-display workspaces only exist on Wayland.** KWin's per-output virtual desktops (MR !8602), which we backported, are Wayland-only by design.
3. **Security and privacy.** On X11, any client can read the screen and log keystrokes. Wayland isolates clients, which fits the privacy goal of this project.
4. **Ubuntu 26.04 is Wayland-first.** Xorg is still packaged but no longer the default anywhere. KWin 6.6 X11 is in maintenance mode.

## Known Wayland limits and what we did about each

| Limit | Impact | What we did |
|---|---|---|
| A client cannot read the screen | The old screenshot tool (`QScreen::grabWindow(0)`) returned black | Ported `cutefish-screenshot` to KWin's `org.kde.KWin.ScreenShot2` D-Bus API; access is granted through `X-KDE-DBUS-Restricted-Interfaces` in its `.desktop` file |
| Screen sharing in browsers or Zoom | Needs a portal | `xdg-desktop-portal-kde` (KWin backend) is in `cutefish-desktop` |
| Native Wayland GTK apps, Firefox, Electron apps cannot export a global menu | Their menu stays inside the window | Qt/KDE apps and XWayland GTK apps (with `appmenu-gtk-module`) show in the bar. Other apps get the fallback menu (app name + Quit). KDE Plasma has the same limit. |
| Old NVIDIA drivers (470 and older) have no GBM | KWin Wayland cannot run on the proprietary driver | Those GPUs use nouveau. `ubuntu-drivers` installs 535+ for newer cards, and those work. |
| X11-only apps | Run through XWayland | XWayland is always started (`--xwayland`) |
| Global hotkeys and screen capture from X11 apps | Limited under XWayland | KWin's xwaylandvideobridge covers screen sharing |

## Verdict

Wayland only. Upstream already did the migration, and every requested feature works better there: per-display Spaces, blur, and privacy.
