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

