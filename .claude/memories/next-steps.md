# Next steps (priority order)

## Session 8 left
- Use `scripts/build-all.sh` for builds; `vm.sh install-debs` to try debs in the live ISO.
- The VM's session-6 install disk is detached: `scripts/vm.sh disk efi attach` puts it back. `--vm-install` replaces the disk with a fresh one and **deletes the old one**.

## Immediately next (session 7 left off here)
1. Not rechecked on the final build: the formats combo snapping back after a failure, and the User name updating in place (framework remastered3).
2. Real hardware: check the power mode actually changes and persists the CPU governor (VirtualBox has no cpufreq).
3. Mouse page lists only Adwaita: the Cutefish cursor themes install to `/usr/share/themes` (known issue below, ask the user first).
4. The rest of `todo-next.md` (features: Settings shortcuts, KDE-style settings, Terminal settings buttons, clipboard manager, native title bars…) is not started.
5. Future (user's plan): publish every `src/<repo>` as its own repo in a private GitHub organization; installed systems then download updates from there. Nothing done yet.

## Session 6 leftovers
The session-6 ISO is built and verified, live and installed (`docs/testing.md` rows 15–16). The VM now boots `build/vm/cutefish-efi/disk2.vdi` (a fresh install; the old `disk.vdi` is kept, detached).
1. Ask the user to open Terminal → right click → Settings (no mouse here).
2. Decide with the user whether LazyVim should stop reaching the network on start (lazy `checker`, Mason), which makes OpenSnitch prompt.
3. Fix the cursor-theme install path (`src/cursor-themes/debian/install` → `/usr/share/icons/`). Ask the user first.

## If you're running inside Cutefish OS (the user's next plan)
You are probably an agent started inside the installed or live Cutefish OS, on real hardware or in a VM.
- `scripts/vm.sh`, Docker and Modal probably don't apply there. You *are* the system under test, so run checks directly (`journalctl --user -b -p warning`, `nmcli`, `bluetoothctl`, `upower -d`, `kscreen-doctor -o`, …).
- Work through `docs/hardware-checklist.md` with the user and record results in `docs/testing.md` (new section with the date and machine model). Log problems in `docs/setbacks.md`.
- To try a fix on the running system:
  1. Rebuild the package elsewhere (Modal from the laptop), or build locally only if the build dependencies are installed.
  2. `sudo dpkg -i` the deb.
  3. Restart the session with `sudo systemctl restart sddm`.

  Commit source changes with `commit_pkg` as usual. `src/` must first be recreated with `scripts/fetch.sh` on a fresh clone; that needs Docker only for KWin, which you can skip.
- Keep in mind: OpenSnitch prompts appear for new outgoing connections, including your own tools (`git`, `curl`, `node`). Allow them, or you'll get "network unreachable" after 30 s.

## Open work
1. **Real-hardware checklist** (`docs/hardware-checklist.md`): Secure Boot, Wi-Fi, hotspot to a phone, Bluetooth audio and mouse, battery/charging, brightness, suspend/resume, touchpad gestures, NVIDIA + `ubuntu-drivers`, sound/mic/HDMI, webcam, MTP, printing, fwupd.
2. **WLAN page on machines without Wi-Fi:**
   - add a `wirelessDeviceAvailable` (or similar) property in `src/cutefish-framework/network` (the Handler or EnabledConnections), with a NOTIFY on device added/removed;
   - use it in `src/settings/src/qml/SideBar.qml` instead of `wirelessHwEnabled`;
   - rebuild the framework and settings.
3. **"Cutefish OS OS Live environment"** on the installer's finish page: check how Calamares 3.3.14 fills `%2` there (branding `productName`/`versionedName`/`shortProductName`), then adjust `packaging/calamares/branding/cutefish/branding.desc`.
4. UI-level checks the harness couldn't do (they need a mouse, i.e. a person or an agent inside the OS):
   - Settings → Appearance → Blur: add or remove an app;
   - the Spaces toggle;
   - the language page;
   - screenshot save to Desktop/clipboard;
   - the global menu in Calculator, Kate, LibreOffice.
5. Optional polish:
   - the lock screen follows the user's wallpaper;
   - the netmonitor portal warning (`App info not found for 'cutefish-netmonitor'`: its desktop file isn't in `/usr/share/applications`);
   - QML binding warnings on the Hotspot page (noted in session 3, not investigated).
6. Distribution: a PPA or apt repo so installed systems get updates (today they don't); CI for the build.
7. Maintenance: when Ubuntu updates kwin 6.6.6 (security), rebase `patches/kwin`. Drop the per-output backport when KWin ≥ 6.7 lands.

## Housekeeping
- Delete the merged branches `claude/serene-volta-p3dnpo` and `claude/loving-turing-i1erb6` (ask the user first).
- The `build/vm/*.sh` helpers are now `scripts/vm.sh` subcommands (session 8).
