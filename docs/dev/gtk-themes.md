# gtk-themes

`cutefish-gtk-themes`: GTK 2, 3 and 4 themes that match FishUI, so GTK apps (Firefox's dialogs, GNOME tools, …) fit in. Upstream is cutefishos/gtk-themes. We haven't changed it.

## Themes

Three themes, installed to `/usr/share/themes/`:

| Theme | Use |
|---|---|
| `Cutefish-light` | Light mode |
| `Cutefish-dark` | Dark mode |
| `Cutefish` | Generic (light) variant; not selected automatically |

Each has:
- `gtk-2.0/`: `gtkrc` plus `main.rc`, `apps.rc` and `hacks.rc`, with `assets/`;
- `gtk-3.0/` and `gtk-4.0/`: a precompiled `gtk.css` (and `gtk-dark.css`), with `assets/`;
- `index.theme`.

The CSS is compiled output. There is no Sass source in this repository, so edits go straight into `gtk.css`. Make them in both the `gtk-3.0` and `gtk-4.0` directories of both the light and dark themes.

## How it is selected

Core's Appearance service writes `~/.config/gtk-3.0/settings.ini` on every dark-mode change ([core.md](core.md)):
- `gtk-theme-name` is `Cutefish-light` or `Cutefish-dark`;
- `gtk-application-prefer-dark-theme` follows dark mode;
- `gtk-cursor-theme-name` and `gtk-cursor-theme-size` follow the cursor settings.

GTK 3 reads that file directly. GTK 4 apps mostly follow `gtk-application-prefer-dark-theme` and the XDG settings portal. libadwaita apps keep their own style and only follow light or dark.

## Testing

Run `GTK_THEME=Cutefish-dark gtk3-widget-factory` (from `gtk-3-examples`) to see every widget, or open any GTK app after switching dark mode in Settings.
