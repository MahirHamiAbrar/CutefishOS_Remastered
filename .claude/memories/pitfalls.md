# Pitfalls that already cost time

## Your own tooling
- `pkill -f PATTERN` / `pgrep -f PATTERN` match your own shell command if it contains PATTERN. This killed the agent's shell twice (exit 144) and left wait loops spinning forever. Use `pkill -x <name>`, or a pattern that isn't in your own command.
- `pgrep -x`/`pkill -x` match the kernel's 15-character process name: `sddm-greeter-qt6` is `sddm-greeter-qt`, `cutefish-settings` is `cutefish-settin`. A longer name never matches, so a wait loop on it hangs.
- A heredoc inside a heredoc: a Python `<<'EOF'` script that itself contains `EOF` ends early. Use another delimiter (`PYEOF`).
- `sleep N; …` chains longer than a few seconds get blocked by the harness. Use `until …; do sleep 10; done` with `run_in_background`, or a Monitor.
- Modal aborts with "modified during build process" if files under the mounted dirs (`src/`, `netmonitor/`, `packaging/`, `scripts/`) change while it uploads.
- Modal's Function runs under gVisor: no `openat2` (shim in `docker/openat2-shim.c`), and `/proc/meminfo` shows the host's RAM, so `JOBS=16` is pinned.
- A background task whose shell is killed by TaskStop reports "failed"; that doesn't mean the work failed. Check the logs.

## Host environment (the user's laptop)
- Docker Desktop (QEMU/KVM VM, ~4 GB) and VirtualBox can't run at the same time (VT-x). Symptom: `docker info` hangs, and `KVM: entry failed, hardware error 0x0` appears in `~/.docker/desktop/log/host/com.docker.backend.log`.
- VBoxHeadless writes `*-VBoxHeadless-*.log` into VBoxSVC's working directory (the repo root); they're gitignored now.
- VirtualBox's NAT accepts host-side connections itself, so a "connected" from the host doesn't mean the guest accepted.
- VirtualBox reports a fake battery; the status bar shows one.

## Packaging and Debian
- `set -e` doesn't apply inside `if ( … )`; chain the steps with `&&`.
- Conffile prompts hang non-interactive `dpkg -i`; use `--force-confmiss`/`--force-confold` as appropriate (see §20).
- Package names in 26.04: `libkscreenlocker6` (no `kscreenlocker` binary package), `firmware-sof-signed`, `cutefish-icon-theme`; there is no GTK2 appmenu.
- `calamares` doesn't depend on `rsync`; libpwquality needs `cracklib-runtime`; there's no `/var/log/syslog` (journald only).
- Desktop-entry `Exec` quoting: only double quotes. Core's session uses `QProcess::splitCommand` (also double quotes only).
- KWin restricted D-Bus interfaces (ScreenShot2 and others) match the caller by the canonical path of `Exec`, so it must be absolute.
- Two packages can't own the same path as a file in one and a directory in the other (`/etc/cutefish`, §20).

## KWin / Qt
- KConfig group names are case-sensitive (`[Effect-blur]`).
- The blur effect fades by `opacity²`; force-blurred windows now ignore the rule opacity (§23).
- `reconfigure` on `/KWin` is delayed 200 ms; `reconfigureEffect blur` reparses the config itself, so the order doesn't matter.
- Firefox on Wayland: resourceName `firefox-bin`, resourceClass `firefox`.
- Qt's `QLocale::system()` follows the environment; core's session sets `LANG`/`LANGUAGE`/`LC_*` from `~/.config/cutefishos/language.conf` (§28).
- NetworkManager's `WirelessHardwareEnabled` is the rfkill switch, not device presence.

## Calamares
- It needs an Internet-check URL that returns a body (§30).
- The live VM keyboard flow and mnemonics: Alt+N (Next), Alt+I (Install), Enter confirms "Install Now". The radio group needs Tab×3 then Space/Down.
- The geoip lookup sets the formats locale (bn_BD from the user's IP) and the timezone Asia/Dhaka. The language stays American English.
- The finished page's `%2` text reads "Cutefish OS OS" (cosmetic, unfixed).

## Boot
- BIOS El Torito uses `grub-mkstandalone`, whose config is in a memdisk. It must `search --file /.disk/info` and then `configfile` the real one (§29). UEFI uses Ubuntu's signed GRUB, which finds the medium itself.
- `loginctl terminate-user` on the live VM wedged the guest.

## Builder image tools (session 6)
- Modal's image has its own Python 3.12 in `/usr/local/bin`, first in `PATH`. It got picked by CMake (Calamares linked libpython3.12 next to Ubuntu's boost_python 3.14) and by `env python3` scripts (`dh_qmldeps`: "No module named 'debian'"). `build-in-container.sh` now sets a system-only `PATH`; our `dpkg-deb` wrapper lives in `/opt/cutefish-build/bin`.
- A `find_package(... QUIET)` that skips a component produces a package that installs fine and lacks the feature. Use REQUIRED, and add the key file to `must` in `build-in-container.sh`.
- KWin's internal C++ API (effects) changes between releases: 6.6 folded `OpenGlContext` into `EglContext`. Rebuild kwin-plugins with every KWin bump.
- In the VM, `pkill -f <pattern>` inside `guestcontrol run /bin/sh -c '…'` kills that shell too when the pattern is in its command line. Use `pkill -x <name>`; Firefox's process is `firefox-bin`.

## Session 7
- `pkexec` is its own package in 26.04 and wasn't installed; anything calling it failed silently. It is now a dependency of core and settings.
- pkexec authorizes its **parent** process: never `QProcess::startDetached("pkexec", …)` ("Not authorized").
- `org.freedesktop.timedate1` (and other polkit-guarded D-Bus calls): set `setInteractiveAuthorizationAllowed(true)` on the interface, or polkit refuses without asking.
- A KWin effect plugin with an undefined symbol aborts `kwin_wayland` on load, which loops SDDM and leaves no desktop. Link with `-Wl,--no-undefined`. To recover in the VM: move the .so away and restart sddm.
- FishUI QML controls sized 0 still paint (Switch had `implicitHeight` 0); they only take clicks where a layout stretches them.
- QML: a GridView height of `count / (width / itemWidth)` divides by 0 before layout and breaks the whole page.
- Slider `onValueChanged` fires for the initial value; write settings in `onMoved`.
