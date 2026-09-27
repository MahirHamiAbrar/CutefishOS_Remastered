# Pitfalls that already cost time

The § numbers point to `docs/setbacks.md`. The full list, kept current, is in `.claude/memories/pitfalls.md`.

## Your own tooling
- `pkill -f PAT` / `pgrep -f PAT` match your own shell when PAT is in its command line. That killed the agent's shell (exit 144) and left wait loops spinning forever. Use `pkill -x <name>`; Firefox's process is `firefox-bin`, Settings' is `cutefish-settin` (15 chars).
- A heredoc inside a heredoc ends early when both use `EOF`: use `PYEOF`/`JS` delimiters.
- Long `sleep` chains get blocked. Wait with `until …; do sleep 5; done` in the background, or a Monitor.
- A task stopped by TaskStop reports "failed"; that doesn't mean the work failed. Check the logs.

## Modal
- Editing anything under `src/`, `netmonitor/`, `packaging/` or `scripts/` while `modal run` uploads aborts it ("modified during build process").
- Always `--detach`: a network drop cancelled a non-detached run mid-KWin. Modal can also preempt a container (~15 min lost).
- It runs under gVisor: no `openat2` (LD_PRELOAD shim), and `/proc/meminfo` shows the host's RAM (`JOBS=16` pinned).
- Its image has Python 3.12 first in `PATH`. The builder forces a system-only `PATH` (§34).

## Packaging
- `set -e` doesn't apply inside `if ( … )`: chain the steps with `&&` (§8).
- A `find_package(... QUIET)` that skips a component yields a package that installs fine but lacks the feature. Use REQUIRED, and list key files in `must` in `build-in-container.sh` (§33).
- A preset `SOURCE_DATE_EPOCH` gave every file the same mtime, so Qt kept running cached old QML after an upgrade (§32).
- Conffile prompts hang a non-interactive `dpkg -i`: use `--force-confold`.
- Two packages can't ship the same path as a file in one and a directory in the other (§20).
- `Package: *` can't carry a version pin (§35). The ISO checks that `calamares` and `kwin-wayland` are our `+cutefish` builds.
- 26.04 names: `pkexec` is its own package, and was missing until core/settings depended on it. Also `libkscreenlocker6`, `firmware-sof-signed`.
- `.desktop` `Exec`: double quotes only (§25). KWin's restricted D-Bus interfaces match callers by the absolute `Exec` path (§21).

## KWin / Qt / QML
- A KWin effect plugin with an undefined symbol aborts `kwin_wayland`, which loops SDDM. Link with `-Wl,--no-undefined`. Recovery: move the `.so` away and restart sddm.
- KWin's internal API changes between releases: rebuild kwin-plugins with every KWin bump.
- KConfig group names are case-sensitive (`[Effect-blur]`, §5). A cached `KSharedConfig` goes stale unless you call `reparseConfiguration()`.
- The blur fades by `opacity²` (§23).
- QML:
  - A control sized 0 still paints but only takes clicks where a layout stretches it (FishUI Switch).
  - `count / (width / itemWidth)` divides by 0 before layout and breaks the whole page. Use `Math.max(1, …)` and `Layout.preferredHeight`.
  - `Slider.onValueChanged` fires for the initial value: write settings in `onMoved`.
- polkit:
  - pkexec authorizes its **parent** process, so never `startDetached("pkexec", …)`.
  - `org.freedesktop.timedate1` and similar need `setInteractiveAuthorizationAllowed(true)`.
  - Commands started outside the logind session (guest control) are refused.
- `QLocale::system()` follows the environment; core sets `LANG`/`LC_*` from `language.conf` (§28).
- NetworkManager's `WirelessHardwareEnabled` is the rfkill switch, not whether a device exists.

## Installer and boot
- Calamares:
  - needs a check URL that returns a body (§30);
  - needs `rsync` and `cracklib-runtime` (§26);
  - there's no `/var/log/syslog` (§27);
  - geoip sets the formats and time zone, not the language.
- The BIOS El Torito GRUB is `grub-mkstandalone`; its root is a memdisk, so it must `search --file /.disk/info` (§29).
- `loginctl terminate-user` froze the live VM. Restart a session with `systemctl restart sddm`.
- The live session is tmpfs: a reboot loses hand-installed debs. Use `vm.sh install-debs` after each boot.

## Cost lessons
- Every packaging bug found only after an ISO build costs another 25 minutes. Test in the live system first, then rebuild the ISO once.
- KWin takes ~15–20 min on Modal; settings or core 2–5 min; the ISO 20–25 min locally; Calamares 3–4 min in the VM.
- Docker Desktop's ~4 GB VM can't build KWin (OOM). Prefer `--modal` for KWin.
