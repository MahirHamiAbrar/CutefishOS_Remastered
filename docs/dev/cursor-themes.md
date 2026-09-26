# cursor-themes

`cutefish-cursor-themes`: two X cursor themes, `Cutefish-Light` and `Cutefish-Dark`, installed by `debian/install` to `/usr/share/themes/cutefish-light` and `/usr/share/themes/cutefish-dark`. Each has 144 cursor files in `cursors/`, including the usual alias symlinks. Upstream is cutefishos/cursor-themes. We haven't changed it.

## Files

```
cutefish-{light,dark}/
  index.theme      [Icon Theme] Name=Cutefish-Light / Cutefish-Dark, Inherits=hicolor
  cursor.theme     the name used when the theme is set as the default cursor
  cursors/         Xcursor files (binary) and alias symlinks (left_ptr, pointer, text, …)
```

The cursors are prebuilt Xcursor binaries. The repository has no SVG sources or build script, so changing a cursor means replacing its Xcursor file, made with `xcursorgen` from PNGs.

## How it is used

- **Choosing a theme:** Settings → Mouse writes `CursorTheme` and `CursorSize` through core's Appearance service. Core passes them to GTK (`settings.ini`) and to KDE/KWin, and KWin draws the cursor on Wayland.
- **The default** is `CursorTheme=default`, core's fallback: the system's default cursor (`/usr/share/icons/default`).

**Known problem:** Xcursor and KWin look for cursor themes only in `icons` directories (`~/.local/share/icons`, `~/.icons`, `/usr/share/icons`, `/usr/share/pixmaps`), never in `/usr/share/themes`. As packaged, these two themes are invisible to KWin and to Settings' cursor list (confirmed in the VM on 2026-09-27: `/usr/share/icons` has no Cutefish cursor theme). The fix is to install them to `/usr/share/icons/` in `debian/install`; check in the VM (`ls /usr/share/icons`, Settings → Mouse) before and after.
- **Looking at a theme:** `XCURSOR_THEME=cutefish-dark XCURSOR_SIZE=48 <app>`, or switch the theme in Settings.
