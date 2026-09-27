# Testing

## VirtualBox

`scripts/vm.sh` drives VirtualBox 7.2. VM files live in `build/vm/`. VirtualBox runs fine on this host next to the loaded `kvm_intel` module (checked: "VT-x w/ nested paging").

```sh
scripts/vm.sh create efi        # or bios
scripts/vm.sh start efi         # headless; open the VirtualBox GUI to interact
scripts/vm.sh shot efi desktop  # screenshots of both displays → build/vm/shots/
scripts/vm.sh run efi /usr/bin/journalctl --user -b -p warning   # needs guest additions (in the ISO)
scripts/vm.sh displays efi 2    # connect the second monitor (1 to unplug it again)
scripts/test-spaces.sh efi      # per-display Spaces check, see multi-display.md
scripts/vm.sh destroy efi
```

The test VM has:

- 4 GB RAM and 4 CPUs;
- VMSVGA graphics with 3D acceleration (KWin gets OpenGL, so blur is real);
- **two monitors** (for per-display Spaces and per-display status bars);
- NAT networking and audio;
- two **USB sticks** through VirtualBox's USB mass-storage controller (base package, no extension pack): `CUTEFISH-NTFS` (NTFS) and `CF-EXFAT` (exFAT), created by `vm.sh` with mkntfs/mkfs.exfat inside the builder container.

## Test plan

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Boots (UEFI and BIOS) | `vm.sh create efi` / `bios`, start | GRUB menu → Plymouth → Cutefish desktop, live user logged in automatically |
| 2 | Session health | `journalctl --user -b -p warning` in the guest | no crashes; no QML `TypeError`/`ReferenceError` from shell, settings, filemanager, terminal, netmonitor |
| 3 | Shell | look at screenshots | status bar, dock, desktop icons; launcher opens (Meta) |
| 4 | Blur | open Files/Settings/Terminal over the wallpaper | frosted translucent windows; Settings → Appearance → Blur: add Firefox, and it turns translucent and blurred |
| 5 | Two displays | `vm.sh displays efi 2`, then `test-spaces.sh efi` | test prints PASS; status bar on both; app menu follows the focused window; Meta+Ctrl+→ switches only the display under the pointer; Meta+W opens the overview on each display; the launcher (Meta) opens on the display under the pointer; `vm.sh displays efi 1` removes the second bar |
| 6 | Global menu | open Calculator, Text Editor, Kate | their menus appear in the status bar and work |
| 7 | Network Monitor | `curl https://example.org` in Terminal | prompt "curl wants to connect to example.org"; Deny blocks, Allow + Forever adds a rule; Settings → Network Monitor lists the connection and the rule |
| 8 | Inbound firewall | from the host: connect to a VM port (NAT port forward) | connection dropped; listed under "Blocked incoming connections" |
| 9 | USB NTFS/exFAT | the file manager's sidebar | both sticks appear, mount, and accept a copied file (ntfs3 read/write) |
| 10 | Wi-Fi + hotspot | in the guest: `sudo modprobe mac80211_hwsim radios=2` | two virtual Wi-Fi cards; Settings → Hotspot starts an AP on one; `nmcli dev wifi connect` from the other works |
| 11 | Bluetooth | Settings → Bluetooth | page loads (no controller in the VM; pairing needs real hardware) |
| 12 | Screenshot | status bar → Control Centre → Screenshot | region select → saved to Desktop / clipboard |
| 13 | Install | Calamares (opens automatically) → erase disk | installs, reboots into Cutefish; live packages removed; `ubuntu-drivers` step logged |
| 14 | Installed system | log in, repeat 2–9 | same results |
| 15 | Session 6 features | live session | Inter / JetBrains Mono (`fc-match`); fish + neolambda; `nvim` loads LazyVim with its treesitter parsers offline and draws correctly in Terminal; Blur & Transparency, Region & Language, Date & Time open with no QML warnings; opacity and corner radius change live |
| 16 | Installer locale | install with the geoip time zone (Asia/Dhaka) | language and formats stay `en_US.UTF-8`; the time zone is Asia/Dhaka; the user's shell is fish with oh-my-fish and LazyVim |

Results and the problems they turned up go into [setbacks.md](setbacks.md) and [known-issues.md](known-issues.md).

## Results

### 2026-09-26: fresh ISO (UEFI VM, shell 0.8+remastered3, meta 26.04.2 → 26.04.3)

| # | Result | Notes |
|---|---|---|
| 1 | UEFI: pass | Live user logged in automatically; guest tools ready 30 s after start. BIOS not run yet |
| 3 | pass | Status bar, dock, launcher. Found: the launcher listed two installers ("Install Cutefish OS" and Calamares' own "Install System"); fixed in meta 26.04.3 (Calamares' entry is diverted) |
| 4 | pass (Cutefish apps) | Settings' sidebar is frosted over the wallpaper; `blur` effect loaded. Per-app blur for Firefox not rechecked |
| 5 | pass (partly) | `test-spaces.sh`: `PASS Virtual-1: Desktop 1 -> Desktop 1, Virtual-2: Desktop 1 -> Desktop 2`. Display 2 has its own status bar and no dock. The launcher opens on the display KWin reports as active (checked on both displays by moving the active output with a KWin script); on display 1 it leaves room for the dock. The app menu shows only on the focused window's display. Keyboard shortcuts and the overview not checked (no way to send Meta combos into the guest yet) |
| 6 | pass (Text Editor) | "Cutefish Text Editor · File" in the status bar |
| — | NetMonitor, NetworkManager, OpenSnitch | running after boot, with no manual fixes (they needed hand fixes on the first boot, see setbacks §16) |

To move KWin's active output in the guest without a mouse, run a KWin script with `workspace.slotSwitchToNextScreen();` (loaded through `org.kde.KWin /Scripting loadScript`, the same way `test-spaces.sh` does).
| 7 | prompt: pass; blocking: see note | `curl https://example.org` from the session: prompt "curl wants to connect to example.org (UDP 10.0.2.3 port 53)", frosted, "Denied in 26 s" countdown; unanswered, it logged `deny` after 30 s. But curl still got HTTP 200: its DNS retry and the HTTPS connection passed while the prompt was open (OpenSnitch applies `DefaultAction=allow` while it's asking). Kept by choice, documented in known-issues.md |
| 9 | pass | Both sticks mounted through udisks from the session (`vm.sh srun`); NTFS uses the kernel `ntfs3` driver; write/read/delete works on both |
| 10 | pass (same-host) | `mac80211_hwsim radios=2`: `nmcli dev wifi hotspot` on wlan0 (WPA2/WPA3), wlan1 connected and got 10.42.0.127 over DHCP through the firewall. Pinging 10.42.0.1 from wlan1 fails only because both ends are on one machine (the kernel answers a local address through `lo`) |
| 2 | fixed | Session log: kscreenlocker's greeter crashed in a loop after the idle lock (setbacks §19); fixed with the Cutefish lock screen. Only other errors: PAM can't load `pam_kwallet5`/`pam_fprintd` (harmless, not installed) |
| — | Lock screen: pass | After the fix, `loginctl lock-session` shows the Cutefish lock screen (blurred wallpaper, clock, avatar, password); Enter unlocks the live user. Wrong and right passwords were checked with `kscreenlocker_greet --testing` and a temporary password |
| 5 | pass | Keyboard shortcuts sent as raw scancodes (`VBoxManage controlvm … keyboardputscancode`, Meta = `e0 5b`/`e0 db`). Meta+Ctrl+← with Virtual-1 active: `Virtual-1=1→0, Virtual-2=1` (unchanged); with Virtual-2 active: `Virtual-2=1→0`, Virtual-1 unchanged. Meta+W opens the overview on both displays, each with its own Desktop strip. `vm.sh displays efi 1` disconnects Virtual-2 and the shell keeps running; `displays efi 2` brings the second status bar back |
| 12 | capture: pass | After the fix in setbacks §21, `cutefish-screenshot` captures through KWin ScreenShot2 and shows the region-select overlay. Saving needs a mouse drag, which the harness can't send |

### 2026-09-26: checks without the VM (cloud container: Docker, no VirtualBox)

These ran in the Ubuntu 26.04 build container, not in a booted system. The VM rows still need the laptop.

| # | Result | Notes |
|---|---|---|
| 11 | page loads (headless) | fishui, libcutefish, qt-plugins and settings built from `patches/`, then `cutefish-settings -m bluetooth` under Xvfb: the Bluetooth page renders with its on/off switch, and there are no QML import errors (`Cutefish.Bluetooth`, `org.kde.bluezqt`). The same with and without `bluetoothd` running (no controller in the container). Still to check in the VM |
| 2 | fixed (settings) | That run showed `main.qml:73: TypeError` on every Settings launch without Wi-Fi hardware; fixed in settings 0.8+remastered4 (setbacks §22) |
| 3 | by design | Display 2's volume/Wi-Fi/battery icons are the control-centre button, which every bar has. Only the system tray (`SystemTray`, StatusNotifierItem icons) is limited to the primary bar (`isPrimaryBar`, `src/shell/src/statusbar/qml/main.qml`). Documented in multi-display.md |
| 4 | code reviewed | Settings writes `ForceBlurClasses=firefox` (Mozilla's `firefox.desktop` → window class `firefox`, Firefox's Wayland app_id) and the `cutefish-blur-firefox` opacity rule (exact match on the resource class). KWin's `reconfigure` reloads the rules and re-evaluates open windows, and `reconfigureEffect("blur")` re-reads the list; the blur patch applies cleanly to KWin 6.6.5's `blur.cpp` and turns a matching window's missing blur region into "whole window". Still to be seen in the VM |
| 8 | config reviewed | `cutefish-firewall.service` loads `/etc/cutefish-firewall.nft` (netmonitor 0.2 path). Policy `drop`, and a log with prefix `cutefish-in:`, which Settings reads with `journalctl -k --grep=cutefish-in:`. That needs the user to be in `adm`; Calamares' `defaultGroups` and casper both add it. Still to be run in the VM |

| — | packages reproduce from git | core, shell, screenshot, netmonitor and meta rebuilt from `patches/` and `packaging/` in a clean container (no laptop state), at the same versions. They contain the fixes: `/usr/share/plasma/shells/org.cutefish.desktop` (cutefish-desktop), `PLASMA_DEFAULT_SHELL` (core's session script), `/etc/cutefish` as a file (core), `/etc/cutefish-firewall.nft` (netmonitor), `Exec=/usr/bin/cutefish-screenshot`, no VBox helper unit (cutefish-hardware) |

**Rebuild before the next ISO:** core 0.8+remastered3, meta 26.04.3, netmonitor 0.2, screenshot 0.8+remastered2, shell 0.8+remastered3 (from the previous session) and settings 0.8+remastered4 (this one).


### 2026-09-26: VM checks of rows 4, 8 and 11 (UEFI VM, packages upgraded in place)

| # | Result | Notes |
|---|---|---|
| 4 | fixed, then pass | Firefox in the blur list turned 90 % opaque but the windows behind it stayed sharp; fixed in kwin `+cutefish2` (setbacks §23). After the fix, a GTK test window at 60 % opacity shows Firefox behind it frosted, and Firefox shows Settings behind it blurred. The list was written the way Settings writes it (kwinrc `ForceBlurClasses` + `kwinrulesrc` rule, then `reconfigure` and `reconfigureEffect blur`); the harness can't click through the Settings UI |
| 8 | pass | NAT port forward host `127.0.0.1:18080` → guest `8080`. The guest dropped the SYN and logged `cutefish-in: IN=enp0s3 … SRC=10.0.2.2 DST=10.0.2.15 … PROTO=TCP … DPT=8080 … SYN`. The live user (in `adm`) reads it with the same `journalctl -k --grep=cutefish-in:` call as Settings. (The host side "connects" because VirtualBox's NAT accepts it before trying the guest) |
| 11 | fixed, then pass | The Bluetooth page loads with no errors. With no controller it showed the switch "on"; it now says "No adapter found" (settings 0.8+remastered5, setbacks §24) |
| 2 | pass (Settings) | settings 0.8+remastered4 in the VM (no Wi-Fi card at first, then with `mac80211_hwsim`): no `TypeError`; Settings opens on the first page |
| 7 | pass (listing) | Settings → Network Monitor lists the connections with app, host:port and protocol, allowed (green) and blocked (red), with totals |

### 2026-09-26: fresh ISO, install, installed system (UEFI VM; kwin +cutefish2, settings remastered5, meta 26.04.4)

| # | Result | Notes |
|---|---|---|
| 1 | UEFI: pass | Fresh ISO: every fix from the last two sessions is present without hand edits. `/etc/cutefish` is core's version file, `/etc/cutefish-firewall.nft` is loaded, there is one installer entry, and no systemd unit failed |
| 2 | pass, one bug fixed | Session log clean except one error: `-qw: 1: Syntax error: Unterminated quoted string`. The installer's autostart entry used single quotes, so the installer never opened by itself (setbacks §25, meta 26.04.5) |
| 13 | pass after 3 fixes | Calamares driven by keyboard (`build/vm/cal-drive.sh`: Alt+N, Tab/arrows/Space to pick "Erase disk", typed user, Alt+I). Fixed on the way: `rsync` missing (§26), no cracklib dictionary (§26), `/var/log/syslog` missing (§27); the fixes were applied by hand in the live system to finish the run, and are in meta 26.04.5. Result: GPT with a 300 MiB EFI partition and ext4 root; live packages (casper, calamares, cutefish-live) purged; `ubuntu-drivers install` ran; `/var/log/installer/{debug,syslog,casper.log,media-info}` saved. Firewall prompts appear for the installer's own lookups (geoip, connectivity check); denied, the welcome page says "not connected to the Internet" |
| 14 | pass, one bug fixed | Boots from disk to SDDM (Cutefish theme), login with the chosen password. Session came up in Bengali although the language was English: fixed in core 0.8+remastered4 (§28). Then repeated: 2 clean log; 3 shell; 4 Settings frosted; 5 `test-spaces.sh` PASS (`VM_USER=testu VM_PASS=…`); 7 prompt for curl; 8 inbound drop logged; 9 NTFS (ntfs3) and exFAT mount and write through udisks |

`vm.sh run`/`srun` and `test-spaces.sh` take the guest account from `VM_USER`/`VM_PASS` (default: the live user) for installed systems.

### 2026-09-26: BIOS (new VM `cutefish-bios`, ISO with core remastered4, meta 26.04.6)

| # | Result | Notes |
|---|---|---|
| 1 | BIOS: fixed, then pass | The first BIOS boot stuck at the GRUB menu (setbacks §29). After the fix: GRUB counts down, Plymouth, the live session logs in by itself |
| 13 | pass | The installer now opens by itself at login (§25) and gets through the firewall (the `cutefish-live-installer` rule; the geoip lookup works). The welcome page still said "not connected" until the check URL was changed (§30, meta 26.04.7; checked by hand in the live system). Erase-disk install with `grub-install --target=i386-pc`, 41 jobs, no errors, nothing fixed by hand; `ubuntu-drivers install` ran |
| 14 | pass | Boots from disk, login works. `LANG=en_US.UTF-8` with `LC_TIME=bn_BD` (English UI, Bengali clock, §28); no failed units; opensnitch and the firewall active; the live installer rule and live packages are gone |

**Final ISO** (meta 26.04.7, sha256 `e7b866a3…0950e`): booted in BIOS; the installer opens by itself, `hasInternet : true`, no requirement warnings.

**Session 6 ISO** (fishui 5, settings 8, terminal 4, meta 26.04.9, sha256 `fa584137…ae32`), EFI VM:

| # | Result | Notes |
|---|---|---|
| 6 | pass | Calculator's menu is in the status bar |
| 15 | pass | Terminal first failed to load (§36) and Neovim drew garbage (§37); fixed and retested. Terminal's own Settings dialog needs a mouse click, not tested |
| 16 | pass | Before the Calamares fork, the same install gave `LC_*=bn_BD` and a Bengali lock screen; now everything is `en_US.UTF-8` and the lock screen is English. The installer removes itself |

