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
