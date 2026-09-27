# Workflow: how to work in this repo

## Layout
```
repos.lock            upstream repos + pinned SHAs
src/<repo>/           upstream clones with our commits on top (NOT in git; recreate with scripts/fetch.sh)
src/kwin-ubuntu/      Ubuntu kwin 4:6.6.6 source + our patches (git repo of its own)
patches/<repo>/       git format-patch of our commits — the source of truth
patches/kwin/         cutefish-per-output-000{1..7}, cutefish-blur-000{1,2}
netmonitor/           our own package (in git directly)
packaging/            meta packages (source cutefish-meta) + calamares settings + files/ (in git directly)
docker/               builder Dockerfile, openat2 shim for Modal
scripts/              build-all.sh, fetch.sh, build-debs.sh, build-in-container.sh, modal_build.py, build-iso.sh, vm.sh, test-spaces.sh, lib-commit.sh
iso-packages.yml      which apps go in the ISO (read by build-all.sh)
build/                gitignored: repo/ (debs + apt index), logs/, vm/ (VirtualBox VMs, shots/), the ISO
docs/                 all documentation; setbacks.md and testing.md are living logs
```

## Changing an upstream package
1. Edit `src/<repo>`. Don't touch `src/` while a Modal build is uploading.
2. `source scripts/lib-commit.sh; commit_pkg <repo> "<message>"`. This bumps `+remasteredN` in `debian/changelog`, commits on top, and re-exports `patches/<repo>/`. `amend_pkg <repo>` folds a follow-up into the last commit.
3. Commit `patches/<repo>` in the main repo. Header-only churn in older patch files is normal.

KWin is different (and since session 7 it carries only the per-output backport; blur is `kwin-plugins/plugins/blur`): commit in `src/kwin-ubuntu`, then `git format-patch -1` into both `patches/kwin/cutefish-…-000N-….patch` and `src/kwin-ubuntu/debian/patches/`. Append the file name to `debian/patches/series` and `.pc/applied-patches`, and bump the changelog `+cutefishN`. Also update the version and changelog line in `scripts/fetch.sh`. `fetch.sh` applies `patches/kwin/*.patch` in glob order (blur before per-output), so check that they apply from a pristine tree.

`netmonitor/` and `packaging/`: edit them directly and bump `debian/changelog` by hand. Meta is at 26.04.7; bump for any change that will be built.

## Building
- Packages on Modal (preferred; 16 CPUs, 32 GiB):
  `MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py --pkgs "settings meta kwin" > build/logs/modal-X.txt 2>&1`
  Package names: repo names, plus `kwin`, `netmonitor` and `meta`. The debs sync back to `build/repo/`, and a Modal volume `cutefish-build` keeps the apt repo. It needs `~/.modal.toml` (only on the laptop). **Use a Modal Function, never a Sandbox** (user rule).
- Packages locally: `scripts/build-debs.sh <pkgs>` in Docker Desktop. It's slow, and KWin can OOM there.
- ISO: `scripts/build-iso.sh` (privileged Docker, about 25 min) → `build/cutefish-os-26.04-amd64.iso`. **Stop VirtualBox VMs first.** The ISO takes the highest version of each package in `build/repo`.
- Docker Desktop: `systemctl --user start|stop docker-desktop`; wait for `docker info`.

## One command: `scripts/build-all.sh` (session 8)
Builds the packages (local Docker by default, `--modal` for Modal), the ISO, and boots it live in `cutefish-efi`, with a progress bar under the scrolling log (`build/logs/build-all-<time>.log`).
- `--skip build,iso,vm` skips steps.
- `--pkgs "…"` limits the build.
- `--vm-install` installs to a fresh disk with Calamares and logs in to the installed system. It **deletes the VM's old disk**.

`iso-packages.yml` decides which apps are in the ISO: build-all.sh writes it into cutefish-desktop's Depends (a marked block in `packaging/debian/control`) and bumps meta when it changes. The project skill `.claude/skills/linux-iso-build-debug/` describes the whole build/test/debug method.

## Trying changes (the user's standard since 2026-09-27)
No ISO rebuild for each change:
1. `scripts/build-all.sh --skip build,iso` boots the current ISO live and waits for the desktop. It detaches the disk, since EFI otherwise boots the installed system; the path is kept in `build/vm/cutefish-efi/disk.path`, and `vm.sh disk efi attach` puts it back.
2. `scripts/vm.sh install-debs efi <debs…>` copies the debs in, runs `dpkg -i --force-confold`, restarts sddm, and waits for the desktop. It logs in again if a greeter appears.

### A mouse for the agent (ydotool), all in `scripts/vm.sh`
- `vm.sh mouse efi`: `apt-get update` + install ydotool (the ISO has no apt lists), start `ydotoold`, and set flat acceleration on its KWin input device. Repeat it after every session start: without flat acceleration, moves are scaled.
- `vm.sh click efi X Y` clicks at display-0 pixels. It moves to the corner and then to X,Y as **separate** ydotool commands; one `mousemove -a` sometimes got merged by libinput and landed elsewhere.
- `vm.sh cursor efi` prints KWin's cursor position; `vm.sh kwin efi 'JS'` evaluates a KWin-script expression (the result goes through Space 2's name, then restored).
- `vm.sh app efi cutefish-settings -m <page>` starts an app through AppRuntime, inside the session. That matters for pkexec/polkit: apps started from guest control directly fail polkit calls.
- Wheel: `ydotool mousemove --wheel -x 0 -y -1` (repeat). Typing: `VBoxManage controlvm … keyboardputstring`.
- Screenshots don't show the pointer; use `vm.sh cursor`.

## Modal
- Use `modal run --detach …`: a network drop cancelled a non-detached run mid-KWin. Modal can also preempt the container (it restarts the function; ~15 min lost). The build logs to the volume, so the console stays quiet while compiling; `modal container exec <id> -- tail /vol/out/logs/<pkg>.log` shows progress.

## Testing in VirtualBox (laptop only)
- `scripts/vm.sh create|start|stop|destroy efi|bios`: VMs `cutefish-efi` and `cutefish-bios`, files in `build/vm/`. Two monitors, 3D, NAT, USB sticks with NTFS and exFAT.
- `vm.sh shot <fw> <name>` saves screenshots of both displays to `build/vm/shots/` (read them with the Read tool).
- `vm.sh run <fw> <cmd…>` runs a command as the guest user through guest control. `vm.sh srun <fw> '<shell cmd>'` runs it inside the graphical session through AppRuntime, which polkit needs for udisks/NM.
- For installed systems: `VM_USER=testu VM_PASS=cutefish123` (the test install's account). The live user is `cutefish` with an empty password.
- Start a GUI app in the session:
  `vm.sh run efi /usr/bin/busctl --user --address=unix:path=/run/user/1000/bus -- call com.cutefish.AppRuntime /AppRuntime com.cutefish.AppRuntime launchCommand sass <appid> <argc> <argv…> /tmp`
- Keys: `VBoxManage controlvm <vm> keyboardputscancode …`:
  - Meta: `e0 5b` / `e0 db`
  - Alt: `38` / `b8`
  - Tab: `0f` / `8f`
  - Enter: `1c` / `9c`
  - Space: `39` / `b9`
  - Down: `e0 50` / `e0 d0`
  - Alt+N (Calamares Next): `38 31 b1 b8`
  - Alt+I (Install): `38 17 97 b8`

  Type text with `keyboardputstring`. Mouse: `vm.sh mouse`/`click` (ydotool, above).
- `vm.sh displays efi 2|1` plugs or unplugs the second monitor. `scripts/test-spaces.sh efi` runs the per-display Spaces test.
- Calamares by keyboard: `vm.sh calamares efi <downs>` then `vm.sh wait-install efi`. The argument is how many Down presses reach "Erase disk": 0 on an empty disk, 2 with an existing install. The account is "Test User" / `testu` / `cutefish123`.
- Restart a session: `sudo systemctl restart sddm` (autologin on live; on installed systems, type the password and Enter). **Don't** use `loginctl terminate-user`.
- The live system is non-persistent: a reboot loses anything installed by hand. To boot an installed disk, power off, `VBoxManage storageattach <vm> --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive`, then start.
- Boot media: `vm.sh dvd efi iso|empty`, `vm.sh disk efi detach|attach [PATH]|fresh`.
- Current VM state (2026-09-28): `cutefish-efi` boots the ISO live with no disk attached (the session-6 install is `build/vm/cutefish-efi/disk2.vdi`). `cutefish-bios` has the BIOS test install and the final ISO attached. The NAT rule `fwtest` forwards host 127.0.0.1:18080 to guest port 8080.
- KWin scripts can't `print` to the journal visibly; publish results by renaming a Space (`workspace.desktops[i].name = …`) and read `org.kde.KWin /VirtualDesktopManager desktops`. Restore the name afterwards.

## Committing
- Commit and push often (`git push origin main`), and end messages with `Co-Authored-By: Claude …`.
- Every setback goes into `docs/setbacks.md` (symptom/cause/fix), every result into `docs/testing.md`, every open limit into `docs/known-issues.md`.
