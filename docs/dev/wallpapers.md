# wallpapers

`cutefish-wallpapers`: the shipped wallpapers (Unsplash licence). Upstream is cutefishos/wallpapers. We haven't changed it.

## Files

`sources/default.jpg` and `sources/wallpaper-1.jpg` … `wallpaper-9.jpg`, installed to `/usr/share/backgrounds/cutefishos/` (`sources/CMakeLists.txt`).

## How they are used

- **The default:** core's Appearance service uses `/usr/share/backgrounds/cutefishos/default.jpg` until the user picks another (`Wallpaper` in `theme.conf`). The SDDM theme always shows `default.jpg`, blurred.
- **Settings → Background:** it lists the framework `Wallpaper` class's `backgrounds()`, which is every image in `backgrounds/cutefishos` under the XDG data directories. So `/usr/share/backgrounds/cutefishos/` and the user's `~/.local/share/backgrounds/cutefishos/` both show up.
- **The desktop:** the shell's desktop surfaces draw the chosen wallpaper ([shell.md](shell.md)).

## Adding a wallpaper

Put the JPEG in `sources/` and add it to `sources/CMakeLists.txt`. To change the default, replace `default.jpg`, since both the SDDM theme and core's fallback use that path.
