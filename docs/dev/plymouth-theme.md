# plymouth-theme

`cutefish-plymouth-theme`: the boot splash. Upstream is cutefishos/plymouth-theme. We haven't changed it.

## Themes

| Theme | Files | Use |
|---|---|---|
| `cutefish-logo` | `cutefish-logo.plymouth`, `cutefish-logo.script`, PNGs (`logo`, `box`, `entry`, `lock`, `bullet`) | The graphical splash: the logo on a near-black background (`0.035` grey), plus the disk-unlock password prompt |
| `cutefish-text` | `cutefish-text.plymouth` | Text fallback |

Both install to `/usr/share/plymouth/themes/` (`debian/install`). `debian/postinst` registers them as the `default.plymouth` and `text.plymouth` alternatives (priority 100) and runs `update-initramfs -u`, because the splash lives in the initramfs.

## How the script works

`cutefish-logo.script` uses Plymouth's script module:
- it centres the logo sprite (`Window.SetBackgroundTopColor`/`BottomColor`, `Sprite(logo.image)`);
- `display_password_callback(prompt, bullets)` shows the lock icon, the entry box and one bullet sprite per typed character (LUKS unlock);
- `display_normal_callback` hides them again.

## Testing

Run these as root:

```sh
plymouthd --debug --tty=/dev/tty2 && plymouth --show-splash; sleep 5; plymouth --quit
```

Otherwise, reboot. The ISO boots with `quiet splash`, and the live system shows the theme.

The Plymouth packages (`plymouth`, `plymouth-label`) come from the ISO build (`scripts/build-iso.sh`), and `cutefish-desktop` depends on this theme. After editing the theme, run `update-initramfs -u`.
