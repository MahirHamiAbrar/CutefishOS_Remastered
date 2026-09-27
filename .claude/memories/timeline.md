# Timeline

The project started on 2026-09-25; everything below happened on 2026-09-25/26. Sessions alternated between the user's laptop (local Claude Code in VS Code) and Claude cloud sessions. A setback number (§N) refers to `docs/setbacks.md`.

## Session 1 (local, 2026-09-25): research, plan, first builds
- Researched the premise and found that upstream Cutefish was revived (§1), which changed the plan. The user approved the plan in plan mode.
- Set up the workspace: `repos.lock`, `scripts/fetch.sh`, `patches/`, `docker/Dockerfile`, `scripts/build-debs.sh`, `docs/`.
- Docker problems:
  - Docker unreachable until the user started Docker Desktop (§2).
  - apt `file:` repo warnings (§3).
  - `cp -a` failed on the virtiofs bind mount (§9).
  - KWin OOM-killed in Docker Desktop's ~4 GB VM (§10).
  - Docker Desktop stopped answering under load (§13).
- **Moved compiles to Modal** (`scripts/modal_build.py` + `scripts/build-in-container.sh`); fixed gVisor's missing `openat2` with an LD_PRELOAD shim (§14).
- Backported KWin MR !8602 (per-output desktops) by cherry-picking 8 commits onto v6.6.6. Vendored the v4 virtual-desktop protocol and dropped the Slide rewrite (§4).
- Blur:
  - Found upstream's `[Effect-Blur]` case bug (§5).
  - Force blur couldn't be done as a plugin, so we patched KWin's blur effect with `ForceBlurClasses` (§6).
- Upstream terminal depended on unpublished framework pieces (§7). Found `set -e` inside `if (...)` hiding build failures (§8).
- Revived the hotspot: the PSK was agent-owned and no secret agent exists (§11). Renamed packages for 26.04 (§12).
- Finished texteditor as a minimum usable app. Ported screenshot and calculator to Qt6.
- First full compile on Modal: Qt6/KWin 6.6 API breaks fixed (§15).
- First live boot in VirtualBox: eight integration bugs fixed (§16), including:
  - `sddm.conf` without a trailing newline broke autologin;
  - NetworkManager unmanaged devices;
  - missing `qt6-svg-plugins`;
  - icon theme renamed upstream;
  - the autostart loader skipped every `OnlyShowIn` entry.

## Session 2 (cloud, branch `claude/serene-volta-p3dnpo`): multi-display
- Per-display status bars; the launcher opens on the active display; `scripts/test-spaces.sh` (a KWin script publishes its result in the name of Space 1).
- The VM's second display: VBoxDRMClient comes from `virtualbox-guest-x11`, and `setscreenlayout` is what works (§17). The session handed off to local because the cloud has no VirtualBox.

## Session 3 (local): fresh ISO, VM testing, many fixes
- The user asked for a watchdog cron job to auto-continue after stalls. It was created, then deleted at the end, as asked.
- Docker Desktop hung because the VM held VT-x (§18). The user allowed restarting Docker Desktop.
- **Incident:** `pkill -f` matched the agent's own command line and killed its shell twice (exit 144). Lesson recorded.
- Removed the redundant VBox helper unit (§17); diverted Calamares' duplicate "Install System" entry.
- Added `vm.sh srun` (runs commands inside the graphical session, where polkit allows udisks/NM).
- USB NTFS/exFAT, hotspot (hwsim) and the Network Monitor prompt verified. Found the OpenSnitch prompt-window gap; the user chose "keep allow, document".
- **Lock screen locked users out**: the kscreenlocker greeter crash-looped with no Plasma installed. Wrote our own lock-screen theme (§19).
- `/etc/cutefish` file-vs-directory conflict between core and netmonitor; netmonitor 0.2 fixed it (§20).
- Screenshot "not authorized": the desktop file's `Exec` must be an absolute path for KWin's restricted interfaces (§21).
- Merged into main and wrote a handoff for a cloud agent.

## Session 4 (cloud, branch `claude/loving-turing-i1erb6`): checks without a VM
- Container only (no VirtualBox, no /dev/kvm); started `dockerd` by hand.
- Fixed the Settings `TypeError` on machines without Wi-Fi (§22, settings remastered4).
- Checked the Bluetooth page headless under Xvfb, reviewed blur and firewall configs, and confirmed the changed packages rebuild from git alone.
- **Incident:** its wait loops used `pgrep -f build-in-container`, which matched their own command line, so they never exited (same trap as `pkill -f`).

## Session 5 (local, this one): verify everything, install to disk
- Built settings remastered4 on Modal. Verified rows 8 (inbound drop logged) and 11 in the VM.
- **Per-app blur didn't blur** (§23). Took two debug KWin builds with temporary `qCWarning` logging. The class matched and blur ran every frame, but KWin fades blur by `opacity²`. Fixed as `cutefish-blur-0002`, KWin `+cutefish2`.
- **Incident:** `loginctl terminate-user` on the live VM wedged the guest (frozen display, guest control dead), and only a hard reset helped. Installed packages were lost, because the live system is tmpfs. Use `sudo systemctl restart sddm` to restart a session instead.
- **Incident:** editing a file under `src/` while a Modal build was uploading aborted the build ("modified during build process"). Don't touch mounted dirs while `modal run` uploads.
- Bluetooth "No adapter found" (§24, settings remastered5).
- Fresh ISO boot: the installer never auto-opened because of single quotes in the desktop Exec (§25).
- **Drove Calamares by keyboard** (`build/vm/cal-drive.sh`). Install failures:
  - rsync missing (§26);
  - cracklib dictionary missing (§26);
  - `/var/log/syslog` missing (§27).
- Installed system came up in Bengali because the installer's geoip picked bn_BD formats and core took the last `/etc/locale.gen` line as the language (§28, core remastered4).
- Asked the user about the installer vs. firewall prompts: they chose to allow the installer (meta 26.04.6).
- **BIOS boot was broken**: the standalone GRUB image's root was its memdisk (§29, `build-iso.sh`).
- Calamares' Internet check always failed, because Calamares needs a response body and Ubuntu's check URL returns 204 (§30, meta 26.04.7).
- The final ISO was built and booted in BIOS; the installer opened by itself with `hasInternet : true`.
- `vm.sh` gained `VM_USER`/`VM_PASS`. VBoxHeadless logs are now gitignored.
- The user plans to boot the OS and run a Claude agent inside it next.

## Session 6 (local, 2026-09-27): Terminal/Calculator, transparency, corners, fonts, shell, installer locale, dev docs
- The user's VM test found Terminal and Calculator never opened (§31), sidebars too opaque, no transparency control.
- Fixed Calculator; extended FishUI with what upstream Terminal expects (user's choice: extend FishUI, not patch Terminal).
- Stale QML caches because Modal presets SOURCE_DATE_EPOCH (§32); the builder now stamps each deb with its changelog date.
- Added window opacity and corner radius settings end to end (core → framework → FishUI → Settings; KWin decoration and effect read theme.conf).
- New Settings pages: Blur & Transparency, Region & Language (formats, keyboard layouts), manual date/time, time-zone search.
- Fonts Inter / JetBrains Mono / Fantasque Sans Mono; fish + oh-my-fish (neolambda) and Neovim + LazyVim seeded into /etc/skel at ISO build.
- Calamares fork (Ubuntu source + patch): the time zone no longer picks language or formats.
- The rounded-corners effect had never been built (§33): libdrm missing behind a QUIET find_package; then KWin 6.6 folded OpenGlContext into EglContext.
- The Calamares fork linked Modal's Python 3.12 (§34); builds now get a system-only PATH.
- Verified rounded corners live in the VM.
- Wrote developer guides for all 21 repositories (`docs/dev/`) and an API generator.

- 2026-09-27 (session 6, later): ISO builds failed on network drops (apt retries added), then on the fork pin (`Package: *` can't take a version pin, §35). The user asked to save mobile data, so build-iso.sh caches the apt downloads and the seeded skel. The skel seed needed libc6-dev, relative symlinks and an explicit treesitter install. The live session exposed Terminal still not starting (§36) and Neovim garbage in it (§37: DCS/APC strings, FBO rendering); fixed in fishui 5 and terminal 4. The Settings Default Applications page id was a duplicate of Date & Time's.
