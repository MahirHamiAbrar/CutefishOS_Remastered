# Status (2026-09-27, session 7)

`main` has the session-7 commits on GitHub. `.gitignore` and `todo-next.md` have uncommitted changes that are the user's; leave them.

## Session 7: Settings bug sweep (todo-next.md "Bugs"), tested by clicking in the live ISO
| Package | Version | What's new |
|---|---|---|
| kwin | 4:6.6.6-0ubuntu0.1+cutefish3 | blur patches dropped; only the per-output backport |
| cutefish-kwin-plugins | 0.8+remastered7 | `cutefish_blur` effect (KWin's blur + force classes + 5th level, strength 1–20); KWin's blur disabled in `/etc/xdg/kwinrc` |
| fishui | 0.8+remastered7 | rounded-rect SegmentedControl; Switch has a real height (clicks landed only on stretched switches) |
| cutefish-settings | 0.8+remastered10 | Background/Mouse/User layouts, per-app notifications, time zone (letterbox, nearest city, polkit flag), formats (no hang), layout icon buttons, battery health bar, About sections, sidebar search, cached animated pages, blur saturation; depends on pkexec |
| cutefish-core | 0.8+remastered8 | power mode saved and re-applied at login; pkexec attached and async; depends on pkexec |
| cutefish-shell | 0.8+remastered4 | per-app notification block list (D-Bus `setAppBlocked`, `notification.conf Blocked=`) |
| libcutefish (cutefish-framework) | 0.7+remastered3 | Accounts: name/picture changes announced after AccountsService applies them |

Verified in the live session (see `docs/testing.md`, Session 7): everything in the table there. Settings 10, core 8 and framework 3 were then installed and rechecked: time zone Set applies Asia/Dhaka, the saved Performance mode is re-applied at login (4 × pkexec cutefish-cpufreq, no prompt), and opening Mouse keeps the pointer speed.
Not verifiable in VirtualBox: the CPU governor itself (no cpufreq).

# Earlier status (2026-09-27, session 6)

`main` is at `bf4ee0f` or later on GitHub. `.gitignore` has an uncommitted change that isn't ours; leave it.

## Session 6 (2026-09-27): ISO rebuilt, live session verified
The last ISO build (`build/logs/iso-build14.txt`) has these; the one before (14:23) had fishui 4, settings 7, terminal 2.

| Package | Version | What's new |
|---|---|---|
| fishui | 0.8+remastered5 | Controls Terminal needs, `windowOpacity`/`windowRadius`, unversioned imports, `parentWindow` on every Window (§36) |
| cutefish-core | 0.8+remastered6 | Appearance `windowOpacity` (0.4–1, default 0.7) and `windowRadius` (0–24, default 14); Inter/JetBrains Mono; `formats` in language.conf |
| libcutefish | 0.7+remastered2 | Appearance `windowOpacity`/`windowRadius` |
| cutefish-settings | 0.8+remastered8 | Blur & Transparency, Window corners, Region & Language, manual date/time, time-zone search; Default Applications id fixed; no xkb "custom" layout |
| cutefish-kwin-plugins | 0.8+remastered5 | Rounded-corners effect actually built (§33), follows the radius live |
| calamares (fork) | 3.3.14-0ubuntu25+cutefish1 | Time zone no longer picks the language/formats; system Python (§34) |
| cutefish-terminal | 0.7+remastered4 | Fantasque Sans Mono; DCS/APC strings consumed and image rendering, so Neovim draws correctly (§37) |
| cutefish-calculator | 0.6+remastered2 | Opens again (§31) |
| meta | 26.04.9 | Fonts, fish + oh-my-fish/neolambda, Neovim + LazyVim seed (parsers built), libc6-dev, Calamares fork |

Verified in the live session of the 14:23 ISO (plus fishui 5, settings 8 and terminal 4 installed by hand):
- `fc-match`: Inter and JetBrains Mono. `/etc/default/locale` is `en_US.UTF-8`; `language.conf` is `en_US`.
- The live user's shell is fish; the neolambda prompt shows; the symlinks in skel are relative.
- 24 treesitter parsers are in skel; `nvim` loads LazyVim offline; LazyVim renders correctly in Terminal.
- calamares and kwin-wayland are `+cutefish`; the fork check in `build-iso.sh` passes.
- Calculator opens, and its menu shows in the global menu.
- Blur & Transparency, Region & Language and Date & Time open with no QML warnings; opacity and radius change live over D-Bus.
- The blur and rounded-window effects are loaded.

Not verified yet: Terminal's own Settings dialog (it needs a mouse click; static check says OK); the installer (next step).
LazyVim on first start: Mason and lazy.nvim's update checker reach the network, so OpenSnitch prompts for curl to api.mason-registry.dev and github.com.

Builder and ISO:
- a package must contain its key files (`must` in `scripts/build-in-container.sh`);
- builds get a system-only PATH;
- the ISO bootstrap pins `+cutefish` versions of (lib)calamares/(lib)kwin (`packaging/files/apt/cutefish-forks.pref`, §35) and fails if `calamares` or `kwin-wayland` isn't ours;
- apt retries downloads 10 times;
- **download cache** (user's request, mobile data): `build/cache/apt` (installed .debs + lists), `build/cache/skel/<key>.tar` (seeded skel), `build/cache/nvim-lazy.tar` (plugin clones). A rebuild downloads only what changed.

Developer guides for every repository under `src/` are in `docs/dev/`.

New known issue: the Cutefish cursor themes install to `/usr/share/themes`, where nothing looks for cursors.

# Earlier status (2026-09-26, end of session 5)

`main` is at `5ae013c` or later on GitHub (`origin`). The working tree is clean.

## Package versions in the final ISO
| Package | Version | Notes |
|---|---|---|
| kwin (kwin-wayland, kwin-common, libkwin6, kwin-data, kwin-dev) | 4:6.6.6-0ubuntu0.1+cutefish2 | per-output desktops backport + ForceBlurClasses + full-strength forced blur |
| cutefish-core | 0.8+remastered4 | autostart XDG rules, lock-screen env, language from LANG |
| cutefish-shell | 0.8+remastered3 | per-display status bars, launcher on the active display |
| cutefish-settings | 0.8+remastered5 | blur page, Spaces toggle, Network Monitor page, hotspot, no-Wi-Fi fix, Bluetooth "No adapter found" |
| cutefish-screenshot | 0.8+remastered2 | Qt6 port, KWin ScreenShot2, absolute Exec |
| cutefish-netmonitor | 0.2 | our own (`netmonitor/`); firewall at `/etc/cutefish-firewall.nft` |
| cutefish-meta (desktop, hardware, privacy, live, calamares-settings-cutefish) | 26.04.7 | |
| everything else from upstream | see `repos.lock` + `patches/` | fishui, framework, qt-plugins, filemanager, terminal, icons, wallpapers, sddm-theme, calculator, texteditor, gtk/cursor/plymouth themes, kwin-plugins |

## Done and verified in VirtualBox
Test plan rows are defined in `docs/testing.md`. All verified on the fresh ISO or on an installed system:
- 1 Boot: **UEFI and BIOS** pass, with autologin into the live session. BIOS was broken until setback §29.
- 2 Session health: clean logs (the only leftovers are harmless portal/app-id and MPRIS messages).
- 3 Shell: status bar, dock, launcher, desktop.
- 4 Blur: Cutefish apps frosted. Per-app force blur verified with Firefox and a GTK test window, after the KWin fix (§23). The list was written the way Settings writes it; the Settings UI itself was not clicked, because the harness has no mouse.
- 5 Two displays: `scripts/test-spaces.sh` PASS on live and installed; Meta+Ctrl+←/→ switches only the active display; overview on both displays; hotplug; launcher and app menu follow the active display.
- 6 Global menu: Text Editor verified (Calculator/Kate not rechecked).
- 7 Network Monitor: prompt appears, deny logged, Settings lists connections. Known gap: other connections pass while a prompt is open (kept by choice).
- 8 Inbound firewall: SYN from the host dropped and logged `cutefish-in:`.
- 9 USB: NTFS (ntfs3) and exFAT mount through udisks and are writable.
- 10 Wi-Fi + hotspot: with `mac80211_hwsim`, the hotspot (WPA2/WPA3) serves DHCP to the second radio.
- 11 Bluetooth page loads; shows "No adapter found" in the VM.
- 12 Screenshot: capture works (KWin authorizes it); saving needs a mouse drag, not tested.
- 13 Install: erase-disk install passes on UEFI and BIOS. The final-ISO BIOS run needed no manual fixes. Live packages are purged, `ubuntu-drivers` runs, logs land in `/var/log/installer`.
- 14 Installed system: boots, logs in, rows 2–9 repeated (UEFI); BIOS install boots and logs in cleanly.
- Lock screen: works after idle and with `loginctl lock-session`. Wrong and right passwords were checked with a temporary password.

## Not tested (needs real hardware or a mouse)
- Real Wi-Fi chips, Bluetooth pairing and audio, battery/charging (VirtualBox fakes a battery), brightness, suspend/resume, touchpad gestures, NVIDIA/`ubuntu-drivers`, Secure Boot on real firmware, webcam, printers, MTP phones, fwupd. The checklist is `docs/hardware-checklist.md`.
- Clicking through the Settings UI (blur list, Spaces toggle, language page): the backends were exercised, the UI clicks were not.
- Global menu with Calculator, Kate, LibreOffice or GTK-on-XWayland apps.
- Screenshot save/clipboard path.
- An upgrade path from an older install (only fresh installs; setback §20 has one manual upgrade note).
- Long-running stability, memory leaks, multi-user.

## Known issues (open, documented in `docs/known-issues.md`)
- Settings shows the WLAN page on machines with no Wi-Fi card. It checks NM's `WirelessHardwareEnabled` (the rfkill switch), not device presence. The fix needs a new property in `cutefish-framework/network`.
- The installer's finish page says "Cutefish OS **OS** Live environment" (cosmetic).
- While an OpenSnitch prompt is open, other unknown connections are allowed (DefaultAction=allow, user's choice).
- Before login, OpenSnitch allows by default (no UI to ask yet).
- No global menu for native Wayland GTK/Firefox/Electron apps (a platform limit).
- Space switches fade instead of sliding (the Slide effect isn't per-output in 6.6).
- We maintain a KWin fork until Ubuntu ships KWin ≥ 6.7.
- The lock screen shows the default wallpaper, not the user's (ponytail comment in the QML).
- A user whose first login saved the wrong language keeps it until they change it in Settings (only affects installs made before core remastered4).
- Bengali formats render with a Qt "OpenType support missing for Noto Sans" warning (harmless); `language-pack-*` for the formats locale isn't installed offline.
- Our packages don't update through apt (no PPA).

## Branches
- `main`: everything.
- `claude/serene-volta-p3dnpo` (session 2) and `claude/loving-turing-i1erb6` (session 4, cloud) are merged into main; they can be deleted.
