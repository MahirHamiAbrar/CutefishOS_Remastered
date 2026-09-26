# Setbacks log

Running log of problems hit while building Cutefish OS Remastered. Format: symptom → cause → fix → where the fix lives.

## 1. The premise changed: upstream Cutefish is alive again
- **Symptom:** The project brief assumed Cutefish was unmaintained Qt5/X11 code (the `cutefishos-ubuntu` forks, last touched 2021–2023).
- **Cause:** In Aug–Sep 2026 the original author (Reion Wong) revived `github.com/cutefishos`. It is already on Qt 6.10, KF6 and Wayland, with CI on Ubuntu 26.04. dock, statusbar and launcher were merged into `shell`, and `screenlocker` was archived in favour of kscreenlocker.
- **Fix:** We build on the revived upstream and pin commits in `repos.lock`. The old forks are only used for apps upstream no longer has (`texteditor`, `cutefish-calamares-settings`).

## 2. Docker unreachable
- **Symptom:** `failed to connect to the docker API at unix:///home/<user>/.docker/desktop/docker.sock`.
- **Cause:** The CLI context pointed at Docker Desktop, which was not running. The system engine socket (`/var/run/docker.sock`) is `root:docker`, and the user is not in the `docker` group.
- **Fix:** The user started Docker Desktop. Note that the Docker Desktop VM has about 4 GB RAM, so big builds (KWin) are slow.

## 3. apt warnings about the local repo
- **Symptom:** `W: Symlinking file  to /var/lib/apt/lists/partial/..._Packages.gz failed`.
- **Cause:** A `file:` apt source on a bind-mounted directory; apt tries to symlink the index files.
- **Fix:** Use a `copy:` URI (`scripts/build-debs.sh`).

## 4. Per-display workspaces are not in Ubuntu 26.04's KWin
- **Symptom:** macOS-style separate Spaces per display need KWin 6.7 ([MR !8602](https://invent.kde.org/plasma/kwin/-/merge_requests/8602)). Ubuntu 26.04 and the Kubuntu backports PPA ship 6.6.6.
- **Fix:** Backported the MR onto Ubuntu's kwin `4:6.6.6-0ubuntu0.1` and shipped it as `4:6.6.6-0ubuntu0.1+cutefish1`. Patches are in `patches/kwin/` and get registered in `debian/patches/series` by `scripts/fetch.sh`.
- **Sub-problems:**
  - Applying the flat MR diff produced dozens of rejects: master had drifted a long way from 6.6. We switched to cherry-picking the MR's 8 individual commits onto the `v6.6.6` tag in a real git clone (`build/kwin-git`), so git could do 3-way merges. Only 7 files conflicted.
  - `org_kde_plasma_virtual_desktop` protocol v4 (`output_entered`, `request_enter_output`) is newer than 26.04's `plasma-wayland-protocols` 1.20.0 (v3). We vendored the v4 XML into `src/wayland/` and pointed `src/wayland/CMakeLists.txt` at it.
  - Upstream rewrote the Slide effect (per-screen `SlideEffectScreen` and the new `AnimationClock` API) after 6.6. Porting it would mean porting AnimationClock too. Instead we kept the 6.6 Slide effect, dropped the slide-only commit (`4f87952c59`), and Cutefish uses the **fadedesktop** effect (updated for per-output by the MR) for Space switches. Known limit: if a user turns Slide back on in per-display mode, all screens slide together.
  - The translucency script conflicted: 6.6 still had `desktopChanged()` where master has `updateAnimation()`. We added the per-screen filter to the 6.6 function.
  - The autotest conflicts were resolved in favour of 6.6, since Ubuntu builds with `-DBUILD_TESTING=OFF`.

## 5. Blur settings silently ignored upstream
- **Symptom:** Cutefish's `kwinrc` sets `NoiseStrength=0`, yet KWin kept adding noise to the blur.
- **Cause:** The group was written `[Effect-Blur]`, but KWin's blur effect reads `[Effect-blur]` (see `blur.kcfg`). KConfig group names are case-sensitive.
- **Fix:** Renamed the group in `kwin-plugins/config/kwinrc` (`patches/kwin-plugins`).

## 6. "Force blur" cannot be done from an effect plugin
- **Symptom:** The plan was a small KWin effect in kwin-plugins that sets `WindowForceBlurRole` on chosen windows.
- **Cause:** In KWin 6.6 that role only keeps blur alive during full-screen effects. The blur region itself comes only from the client (the blur protocol / `_KDE_NET_WM_BLUR_BEHIND_REGION`), so an outside effect cannot add one.
- **Fix:** We already ship our own KWin build, so the blur effect got a `ForceBlurClasses` option (`patches/kwin/cutefish-blur-0001-force-blur-classes.patch`). The translucency needed to see the blur comes from ordinary KWin window rules (`kwinrulesrc`, `opacityactive`/`opacityinactive`), which Settings writes. No new plugin.

## 7. Upstream `terminal` is ahead of the published framework
- **Symptom:** `CMake Error: Could not find a package configuration file provided by "CutefishFramework"`, and `FishUI.HeaderButton` is not a type.
- **Cause:** Terminal's Qt6 port (2026-09-23) uses a `CutefishFramework` CMake package (`Application` component, `cutefishapplication.h`) and a FishUI control that were not pushed upstream yet.
- **Fix:** Terminal builds the framework's static `applications` library from the sibling checkout, as Settings and Files already do. It sets its desktop file name itself and uses `FishUI.RoundImageButton` with FishUI's `add.svg` (`patches/terminal`).

## 8. Build failures reported as "ok"
- **Symptom:** The build log said `ok`, but no `.deb` appeared (terminal, gtk-themes, cursor-themes).
- **Cause:** In bash, `set -e` is ignored inside a compound command used as an `if` condition, so a failing `dpkg-buildpackage` inside `if ( … ); then` did not stop the chain.
- **Fix:** The steps are chained with `&&` in `scripts/build-debs.sh`.

## 9. `cp -a` fails on the Docker Desktop bind mount
- **Symptom:** `cp: failed to preserve ownership … Operation not permitted` in `dh_install`.
- **Cause:** Docker Desktop shares the workspace through virtiofs, which refuses `chown` from the container's root.
- **Fix:** Sources are copied into a Docker volume (`cutefish-build`) and built there. As a bonus that filesystem is much faster, and the build tree survives between runs (`RESUME=1`).

## 10. KWin build killed by the OOM killer
- **Symptom:** `c++: fatal error: Killed signal terminated program cc1plus` about 300 files into KWin.
- **Cause:** Docker Desktop's VM has about 3.7 GB RAM. `make -j8` plus Ubuntu's default `-flto=auto` needs roughly 1 GB per compiler process.
- **Fix:** `-j` is now derived from the container's RAM (1 job per 1.5 GB), and LTO is turned off with `DEB_BUILD_MAINT_OPTIONS=optimize=-lto`. It is still slow; giving Docker Desktop more memory (Settings → Resources) speeds it up a lot.

## 11. Hotspot was hidden and would not have worked
- **Symptom:** Settings had a Hotspot page, but it was commented out of the sidebar.
- **Cause:** `Handler::createHotspot()` marked the WPA2 PSK `AgentOwned`. NetworkManager strips agent-owned secrets and asks a secret agent for them, and Cutefish has no secret agent, so activation fails with "no secrets". The page also never showed whether the hotspot was actually running, and accepted passwords WPA2 rejects (fewer than 8 characters).
- **Fix:** The PSK is stored by NetworkManager (flags `None`; the connection is volatile anyway). Activation errors are reported. The page tracks `hotspotCreated`/`hotspotDisabled`, validates 8–63 characters and is back in the sidebar (`patches/cutefish-framework`, `patches/settings`).

## 12. Package names that changed in 26.04
- `kscreenlocker` has no binary package of that name; the library is `libkscreenlocker6`.
- `sof-firmware` is `firmware-sof-signed` on Ubuntu.
- The `texteditor` in `cutefishos-ubuntu` is an empty fork (README only). The real code is in the archived `cutefishs/texteditor`, and it was an unfinished prototype: a hard-coded test file path, no way to open or save, no install rules. We finished the minimum: command-line files, File menu (global menu), open/save dialogs, install rules.

## 13. Docker Desktop stopped responding
- **Symptom:** `docker ps` hung for minutes. The build container sat idle, and the host load dropped to about 1.
- **Cause:** Docker Desktop runs containers in a QEMU VM limited to 3.9 GB RAM. Parallel C++ compiles (and a second container) pushed it into memory thrashing, and the Docker daemon inside the VM stopped answering.
- **Fix:** The compile step moved to a Modal Function (16 cores, 32 GiB) through `scripts/modal_build.py`. The build steps were pulled out into `scripts/build-in-container.sh`, so Docker (`build-debs.sh`) and Modal run exactly the same code. The ISO step still runs locally, because it needs a privileged container (mount/chroot), which Modal's gVisor sandboxes don't offer.

## 14. Modal: `tar` fails with "Function not implemented"
- **Symptom:** On Modal, every copy through `tar` and every `dpkg-deb --build` failed with `Cannot stat: Function not implemented`.
- **Cause:** Modal runs functions under gVisor. `strace` showed `openat2(...) = -1 ENOSYS`: GNU tar (through gnulib) walks paths with `openat2(2)`, which gVisor doesn't implement, and it has no fallback.
- **Fix:**
  - `docker/openat2-shim.c`, an `LD_PRELOAD` library, maps `openat2` (both the glibc wrapper and the raw `syscall(SYS_openat2)`) to `openat`. It is built and preloaded only in the Modal image.
  - The source copy in `build-in-container.sh` uses `cp -a` instead of a tar pipe.
  - Also found while debugging: gVisor's `/proc/meminfo` reports the host's RAM (679 GB), so the job count on Modal is pinned with `JOBS=16`.

## 15. First full compile: Qt 6 and KWin 6.6 API breaks
Found by the first complete build on Modal. All are fixed in `patches/`.

| Package | Error | Fix |
|---|---|---|
| settings | `invalid use of incomplete type 'QDBusPendingCall'` (our new `windoweffects.cpp`) | include `<QDBusPendingCall>` |
| screenshot | `incomplete type 'QFile'` | Qt 6 no longer includes it transitively: `#include <QFile>` |
| calculator | `no match for operator= (QChar and QString)` | `QLocale::decimalPoint()` returns `QString` in Qt 6: `.at(0)` |
| texteditor | `Pointer Meta Types must either point to fully-defined types` | moc in Qt 6 needs the complete type: `#include <QQuickTextDocument>` instead of a forward declaration |
| kwin-plugins | `prePaintWindow … marked 'override', but does not override` | Upstream's rounded-corners effect targets the pre-6.6 effect API. Ported it to KWin 6.6: new `RenderView *` parameter, `KWin::Region` instead of `QRegion`. |
| terminal | `links to Cutefish::Application but the target was not found`; `proxysettings.h: No such file` | More unpublished upstream framework pieces. The QML plugin links our in-tree `Cutefish::Applications` (built PIC, since the plugin is a shared module). A local `qmltermwidget/lib/proxysettings.h` reads the same proxy settings as the session's `NetworkProxyManager`. |
| cutefish-desktop | depends on `cutefish-icons` | The package is called `cutefish-icon-theme` |

## 16. First live boot in VirtualBox: eight integration bugs
The ISO booted to a login screen instead of the desktop. Each problem below was found in the running VM (VirtualBox guest control plus screenshots), confirmed by hand in the VM, and then fixed at the source.

| Symptom | Cause | Fix |
|---|---|---|
| Plain SDDM greeter, no autologin; log: `theme "cutefish[Autologin]" doesn't exist` | Upstream `sddm-theme` installs `/etc/sddm.conf` **without a trailing newline**. casper appends `[Autologin]`, which fuses into `Current=cutefish[Autologin]`, breaking both the theme and the autologin. | Newline added (`patches/sddm-theme`) |
| **No network**: `enp0s3 … unmanaged` | Ubuntu's `network-manager` ships `unmanaged-devices=*,except:type:wifi,…`. Desktop images override it with an empty `/etc/NetworkManager/conf.d/10-globally-managed-devices.conf`, and ours lacked it. | `cutefish-hardware` ships the empty override |
| Dock shows no app icons | Every Cutefish icon is SVG, but Qt 6's SVG icon engine (`qt6-svg-plugins`) wasn't installed. Upstream `fishui` never declared it. | `fishui` and `cutefish-desktop` depend on `qt6-svg-plugins` |
| Icon theme ignored | `qt-plugins` and `core` still asked for the old theme names `Crule`/`Crule-dark`, but the icons repo renamed them to `Cutefish-Light`/`Cutefish-Dark` on 2026-09-05 | Names updated; old `Crule` settings still mean "follow dark mode" (`patches/qt-plugins`, `patches/core`) |
| Files, Calculator, Screenshot and the avatar show generic icons | The new Colloid-based icon set has no `file-system-manager`, `cutefish-calculator`, `cutefish-screenshot` or `default-user` | Alias symlinks in the icon theme (`patches/icons`); `breeze-icon-theme` installed, since the theme inherits from it |
| Mission Control (Overview) doesn't load: `module "org.kde.milou" is not installed` | KWin's Overview QML imports milou (search) | `cutefish-desktop` depends on `milou` |
| Network Monitor and the live installer never start | The session's autostart loader skipped **every** entry with an `OnlyShowIn` key, including `OnlyShowIn=Cutefish;` | Autostart now follows the XDG rules (OnlyShowIn/NotShowIn, Hidden, TryExec, user overrides), reusing the framework's desktop-file parser (`patches/core`) |
| `cutefish-core` can't be installed: `appmenu-gtk2-module` has no candidate | GTK 2 is gone from 26.04 | Dependency dropped |

Found while testing the Network Monitor (it works: the prompt appears, connections and rules show up in Settings):
- The prompt window's height collapsed to the title bar on KWin Wayland, so it got a fixed size.
- Ubuntu 26.04 syncs time with **chrony**, not systemd-timesyncd, so an allow rule for `/usr/sbin/chronyd` was added.
- OpenSnitch's eBPF modules are a separate package (`opensnitch-ebpf-modules`), now a dependency. Without them the daemon falls back to the slower `/proc` monitor.
- `curl` was added to the desktop.

## 17. The VM's second display never connected
- **Symptom:** The VM has two monitors, but the guest only saw `Virtual-1`: `/sys/class/drm/card0-Virtual-2` stayed `disconnected`, and `kscreen-doctor -o` listed one output. `VBoxManage controlvm … setvideomodehint … 1 yes …` changed nothing.
- **Cause:** Under VMSVGA, the host's monitor layout reaches the guest's `vmwgfx` driver only through **VBoxDRMClient**. Ubuntu ships it in `virtualbox-guest-x11`, which we didn't install, and starts it only from an X11 `Xsession.d` hook, so a Wayland session never gets it. With it running, `setvideomodehint` *still* did nothing. VirtualBox 7's `setscreenlayout` did.
- **Fix:** `cutefish-hardware` depends on `virtualbox-guest-x11` and ships `cutefish-vbox-drmclient.service`, which runs VBoxDRMClient as root, only under `ConditionVirtualization=oracle`. `scripts/vm.sh displays` sends the layout with `setscreenlayout`. With that, Virtual-2 connected at 1280,0 with its own status bar and no dock, as designed.
- **Also found:** the D-Bus `current` Space is per *active* output, so it can't show whether Spaces are per display. `scripts/test-spaces.sh` checks per-display Spaces with a KWin script instead (see [multi-display.md](multi-display.md)).

## 18. Docker Desktop hangs while a VirtualBox VM is running
- **Symptom:** `docker info` never returned, the Docker Desktop socket didn't answer `/_ping`, and restarting Docker Desktop left it in `"docker":"starting"` forever. The ISO build stalled before it started.
- **Cause:** Docker Desktop for Linux runs its engine in a QEMU/KVM VM. While a VirtualBox VM is running, VirtualBox holds VT-x, and Docker's VM fails with `KVM: entry failed, hardware error 0x0` (in `~/.docker/desktop/log/host/com.docker.backend.log`).
- **Fix:** Power off the VirtualBox test VM (`scripts/vm.sh stop efi`), then restart Docker Desktop (`systemctl --user restart docker-desktop`). It came up in 10 seconds. Don't run the ISO build and a test VM at the same time.
