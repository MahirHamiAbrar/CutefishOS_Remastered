# Known issues and limits

| Issue | Why | Workaround / plan |
|---|---|---|
| Native Wayland GTK apps, GTK 4, Firefox, Electron: no global menu | They have no way to export menus on Wayland (KDE Plasma has the same limit) | Run a single app with `GDK_BACKEND=x11`; see [global-menu.md](global-menu.md) |
| Switching Spaces fades instead of sliding | KWin 6.6's Slide effect is not per-output; the per-output Slide needs KWin 6.7's new animation API | Goes away when we move to KWin ≥ 6.7 |
| We maintain a KWin fork (6.6.6 + backport + blur option) | Needed for per-display Spaces and per-app blur | Rebase `patches/kwin` on each Ubuntu KWin security update; drop the backport when 6.7 arrives |
| Our Cutefish packages don't update through apt | They come from this build, not a PPA | Rebuild and reinstall; publishing a PPA would be the next step |
| NVIDIA 470 and older on Wayland | No GBM support in the legacy driver | nouveau is used |
| Bluetooth can't be tested in VirtualBox | No virtual controller | Real-hardware checklist |
| Before login, OpenSnitch allows by default (logged) | There is no UI to ask yet | Set `DefaultAction` to `deny` in `/etc/opensnitchd/default-config.json` and add rules for the system services you use |
| While a prompt is open, other unknown connections are allowed (including the app's own retry) | OpenSnitch 1.6.9 applies `DefaultAction` (ours: `allow`) to every unknown connection while the UI is asking; it doesn't queue them | Kept by choice (2026-09-26). For strict blocking, set `DefaultAction` to `deny` in `/etc/opensnitchd/default-config.json` and add rules for your system services; see [privacy-netmonitor.md](privacy-netmonitor.md) |
| `/tmp/osui.sock` could be taken over by another local user | OpenSnitch's default UI socket | Point `Server.Address` at a path only you can create, on shared machines |
| Upstream `terminal` depends on unpublished framework and FishUI parts | Upstream work in progress | Our patch; drop it when upstream publishes |
| Text editor is basic | The original was an unfinished prototype | Tabs, syntax highlighting, open/save, global menu only |
| Settings shows the WLAN page on machines with no Wi-Fi card | Settings hides it only when NetworkManager's `WirelessHardwareEnabled` is false, which is the rfkill hardware switch, not device presence | The page is empty (a switch and "Add other…"). Needs a "has a Wi-Fi device" property in cutefish-framework's network module |
| Installer finish page says "Cutefish OS OS Live environment" | Cosmetic, from Calamares' finished-page string and our branding names | None needed |
| Cutefish cursor themes can't be selected | `cutefish-cursor-themes` installs them to `/usr/share/themes/`; Xcursor and KWin only search `icons` directories (confirmed in the VM, 2026-09-27) | The system default cursor is used. Fix: install to `/usr/share/icons/` in the package's `debian/install`; see [dev/cursor-themes.md](dev/cursor-themes.md) |
