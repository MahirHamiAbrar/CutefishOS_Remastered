# Build and VM harness

All paths are relative to the repo root. `efi` can be `bios` wherever a firmware is taken (VMs `cutefish-efi`, `cutefish-bios`).

## Pipeline: `scripts/build-all.sh`
```
scripts/build-all.sh [--skip build,iso,vm] [--modal] [--pkgs "settings core"] [--vm-install]
```
- **build**: compiles and packages the debs into `build/repo/`.
  - Local Docker by default (starts Docker Desktop; image `cutefish-builder`: `docker build -t cutefish-builder docker/`). `--modal` builds on Modal instead.
  - Packages: `--pkgs`, or every app in `iso-packages.yml` plus `meta`. The build order is fixed by `ORDER` in `scripts/build-in-container.sh`.
  - Checks that every yml package has a deb.
- **iso**: `scripts/build-iso.sh` (privileged Docker, ~20–25 min) → `build/cutefish-os-26.04-amd64.iso`. It takes the highest version of each package in `build/repo`.
- **vm**: boots the ISO live in `cutefish-efi` (disk detached, its path kept in `build/vm/cutefish-efi/disk.path`), waits for `cutefish-shell`, and saves a screenshot `build/vm/shots/cutefish-efi-build-all-live-display0.png`.
  - `--vm-install` puts a **fresh empty disk** in the VM (the old disk is deleted), installs with Calamares by keyboard, boots the installed system, and logs in as `testu` / `cutefish123`.
- The output scrolls above a progress bar and is logged to `build/logs/build-all-<time>.log`; per-package logs are `build/logs/<pkg>.log`, ISO logs `build/logs/iso-*.log`.
- `iso-packages.yml` decides the ISO's apps. build-all.sh writes it into cutefish-desktop's Depends (the marked block in `packaging/debian/control`) and bumps meta when it changes. With `--skip build`, a changed yml stops the ISO step.

Lower-level equivalents:
- `MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run --detach scripts/modal_build.py --pkgs "…"`
- `scripts/build-debs.sh <pkgs>` (local Docker)
- `scripts/build-iso.sh`
- `scripts/fetch.sh` (recreate `src/`)

## Docker Desktop vs VirtualBox
They can't run at the same time (both need VT-x). Symptoms: `docker info` hangs, and `KVM: entry failed, hardware error 0x0` appears in `~/.docker/desktop/log/host/com.docker.backend.log`. build-all.sh switches between them itself. By hand:
- `systemctl --user start|stop docker-desktop`, then wait for `docker info`;
- `VBoxManage controlvm cutefish-efi poweroff`.

## `scripts/vm.sh`
| Command | What it does |
|---|---|
| `create/start/stop/destroy efi` | VM lifecycle: 2 monitors, 3D, NAT, USB sticks with NTFS and exFAT, headless start |
| `dvd efi iso\|empty` | Insert the built ISO / eject it |
| `disk efi detach\|attach [PATH]\|fresh` | Live boot needs the disk detached (EFI otherwise boots the installed system); `fresh` **deletes** the old disk |
| `wait-desktop efi [s]` | Wait until `cutefish-shell` runs |
| `shot efi NAME` | Screenshot of each display → `build/vm/shots/` (Read the PNG) |
| `run efi CMD…` | Run a command as the guest user (guest control), outside the graphical session |
| `srun efi 'SHELL'` | Run it inside the session through AppRuntime: polkit then sees an active session (udisks, NM) |
| `app efi ID [ARG…]` | Start a GUI app inside the session (`cutefish-settings -m blur`) |
| `install-debs efi DEB…` | Copy, `dpkg -i --force-confold`, restart sddm, log in again |
| `mouse efi` | Install and start ydotool; flat acceleration on its KWin input device |
| `click efi X Y` | Left-click at display-0 pixels (corner first, then move: one combined move sometimes landed elsewhere) |
| `cursor efi` | KWin's cursor position |
| `kwin efi 'JS'` | Value of a KWin-script expression (published through Space 2's name, then restored) |
| `calamares efi DOWNS` | Erase-disk install by keyboard; DOWNS = 0 on an empty disk, 2 with an install |
| `wait-install efi` | Wait until that install finished (target unmounted, no failure in the session log) |
| `displays efi 2\|1` | Plug or unplug the second monitor |
| `type efi TEXT` | Type text |

Accounts:
- The live user is `cutefish` with an empty password (the default).
- The installed test system is `VM_USER=testu VM_PASS=cutefish123 scripts/vm.sh …`.

Other tools:
- `scripts/test-spaces.sh efi` runs the per-display Spaces test.

## Guest details
- Start an app inside the session by hand:

  ```
  busctl --user --address=unix:path=/run/user/1000/bus -- call com.cutefish.AppRuntime /AppRuntime com.cutefish.AppRuntime launchCommand sass <appid> <argc> <argv…> /tmp
  ```

  Apps started from guest control directly get no session: polkit and pkexec calls fail there.
- Keys go in with `VBoxManage controlvm <vm> keyboardputscancode` (press, then release):

  | Key | Press / release |
  |---|---|
  | Meta | `e0 5b` / `e0 db` |
  | Alt | `38` / `b8` |
  | Tab | `0f` / `8f` |
  | Enter | `1c` / `9c` |
  | Space | `39` / `b9` |
  | Down | `e0 50` / `e0 d0` |

  In Calamares, Alt+N is `38 31 b1 b8` (Next) and Alt+I is `38 17 97 b8` (Install). Text goes in with `keyboardputstring`.
- Mouse wheel: `ydotool mousemove --wheel -x 0 -y -1`, with `YDOTOOL_SOCKET=/tmp/.ydotool_socket`.
- KWin scripts can't print anywhere readable. Publish a result by renaming a Space (`workspace.desktops[i].name`), read it through `org.kde.KWin /VirtualDesktopManager desktops`, then restore the name (`vm.sh kwin` does this).
- After a restart, SDDM shows the greeter even on live: press Enter (live) or type the password.
- The NAT rule `fwtest` forwards host 127.0.0.1:18080 to guest port 8080 (inbound-firewall tests).
- VirtualBox fakes a battery and has no cpufreq: power/governor and battery-health results need real hardware (`docs/hardware-checklist.md`).
- VBoxHeadless writes `*-VBoxHeadless-*.log` into its working directory (gitignored).
