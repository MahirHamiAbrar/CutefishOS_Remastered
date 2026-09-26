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
scripts/              fetch.sh, build-debs.sh, build-in-container.sh, modal_build.py, build-iso.sh, vm.sh, test-spaces.sh, lib-commit.sh
build/                gitignored: repo/ (debs + apt index), logs/, vm/ (VirtualBox VMs, shots/), the ISO
docs/                 all documentation; setbacks.md and testing.md are living logs
```

## Changing an upstream package
1. Edit `src/<repo>`. Don't touch `src/` while a Modal build is uploading.
2. `source scripts/lib-commit.sh; commit_pkg <repo> "<message>"`. This bumps `+remasteredN` in `debian/changelog`, commits on top, and re-exports `patches/<repo>/`. `amend_pkg <repo>` folds a follow-up into the last commit.
3. Commit `patches/<repo>` in the main repo. Header-only churn in older patch files is normal.

KWin is different: commit in `src/kwin-ubuntu`, then `git format-patch -1` into both `patches/kwin/cutefish-…-000N-….patch` and `src/kwin-ubuntu/debian/patches/`. Append the file name to `debian/patches/series` and `.pc/applied-patches`, and bump the changelog `+cutefishN`. Also update the version and changelog line in `scripts/fetch.sh`. `fetch.sh` applies `patches/kwin/*.patch` in glob order (blur before per-output), so check that they apply from a pristine tree.

`netmonitor/` and `packaging/`: edit them directly and bump `debian/changelog` by hand. Meta is at 26.04.7; bump for any change that will be built.

## Building
- Packages on Modal (preferred; 16 CPUs, 32 GiB):
  `MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py --pkgs "settings meta kwin" > build/logs/modal-X.txt 2>&1`
  Package names: repo names, plus `kwin`, `netmonitor` and `meta`. The debs sync back to `build/repo/`, and a Modal volume `cutefish-build` keeps the apt repo. It needs `~/.modal.toml` (only on the laptop). **Use a Modal Function, never a Sandbox** (user rule).
- Packages locally: `scripts/build-debs.sh <pkgs>` in Docker Desktop. It's slow, and KWin can OOM there.
- ISO: `scripts/build-iso.sh` (privileged Docker, about 25 min) → `build/cutefish-os-26.04-amd64.iso`. **Stop VirtualBox VMs first.** The ISO takes the highest version of each package in `build/repo`.
- Docker Desktop: `systemctl --user start|stop docker-desktop`; wait for `docker info`.

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

  Type text with `keyboardputstring`. There is **no mouse** injection.
- `vm.sh displays efi 2|1` plugs or unplugs the second monitor. `scripts/test-spaces.sh efi` runs the per-display Spaces test.
- Calamares by keyboard: `build/vm/cal-drive.sh <downs>` (gitignored; `FW=bios` for the BIOS VM). The argument is how many Down presses reach "Erase disk": 0 on an empty disk, 2 with an existing install.
- Restart a session: `sudo systemctl restart sddm` (autologin on live; on installed systems, type the password and Enter). **Don't** use `loginctl terminate-user`.
- The live system is non-persistent: a reboot loses anything installed by hand. To boot an installed disk, power off, `VBoxManage storageattach <vm> --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive`, then start.
- Current VM state: `cutefish-efi` has the UEFI test install on its disk and no DVD. `cutefish-bios` has the BIOS test install and the final ISO attached. The NAT rule `fwtest` forwards host 127.0.0.1:18080 to guest port 8080.
- KWin scripts can't `print` to the journal visibly; publish results by renaming a Space (`workspace.desktops[i].name = …`) and read `org.kde.KWin /VirtualDesktopManager desktops`. Restore the name afterwards.

## Committing
- Commit and push often (`git push origin main`), and end messages with `Co-Authored-By: Claude …`.
- Every setback goes into `docs/setbacks.md` (symptom/cause/fix), every result into `docs/testing.md`, every open limit into `docs/known-issues.md`.
