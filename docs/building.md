# Building

Everything is built inside an Ubuntu 26.04 Docker container, so the host (Ubuntu 24.04 here) only needs Docker, git and, for testing, VirtualBox.

## Once

```sh
docker build -t cutefish-builder docker/
```

## 1. Get the sources

```sh
scripts/fetch.sh            # clone/checkout the pinned commits in repos.lock and apply patches/
scripts/fetch.sh --update   # move to the latest upstream commits instead (re-pins repos.lock)
```

`fetch.sh` also downloads Ubuntu's `kwin` 4:6.6.6-0ubuntu0.1 source into `src/kwin-ubuntu`, applies `patches/kwin/*.patch`, registers them in `debian/patches/series` and bumps the version to `+cutefish2`.

After `--update`, patches that no longer apply stop `git am`. Fix them in `src/<repo>`, then re-export them (see "Changing a package").

## 2. Build the packages

Two ways to run the same build (`scripts/build-in-container.sh` in the image from `docker/Dockerfile`):

### On Modal (fast; used for this project)

```sh
python3 -m venv .venv && .venv/bin/pip install modal   # once; credentials in ~/.modal.toml
MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py                    # everything
MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py --pkgs "settings shell"
```

- It runs as a Modal **Function** with 16 cores and 32 GiB, with a 2-hour cap per run. The image is built from `docker/Dockerfile`, and the sources are uploaded from `src/`, `netmonitor/` and `packaging/` (excluding `.git` and build trees).
- The package repository is kept in the Modal volume `cutefish-build` (`out/repo`), so later runs build against earlier packages. After every run `build/repo` and `build/logs` are synced down.
- Cost: about $1 per hour of build time on Modal's Function pricing. A full build takes under an hour.

### Locally in Docker

```sh
scripts/build-debs.sh                 # everything, in dependency order (KWin last)
scripts/build-debs.sh settings shell  # only these
RESUME=1 scripts/build-debs.sh kwin   # continue an interrupted build without cleaning
JOBS=6 scripts/build-debs.sh kwin     # override the parallel job count
```

- Output: `build/repo/*.deb` plus a `Packages` index. The local repo is also used to resolve build dependencies between our packages.
- Logs: `build/logs/<package>.log`.
- Sources are copied into the Docker volume `cutefish-build` and compiled there (see setbacks 9 and 10). `docker volume rm cutefish-build` throws all build trees away.
- The number of parallel jobs is taken from the container's RAM (1 per 1.5 GB). LTO is off.
- **Build time:** with Docker Desktop's default 4 GB VM, KWin alone takes several hours at `-j2`. Give Docker Desktop more memory (Settings → Resources → Memory, e.g. 10 GB) and the job count goes up automatically.

## 3. Build the ISO

```sh
scripts/build-iso.sh   # → build/cutefish-os-26.04-amd64.iso (+ .sha256)
```

This runs a **privileged** container. `mmdebstrap` builds the root filesystem from the Ubuntu archive, our `build/repo` and Mozilla's Firefox repository. The script then installs:

- `cutefish-desktop cutefish-hardware cutefish-privacy cutefish-live calamares-settings-cutefish`
- `casper` and the signed boot chain (`shim-signed`, `grub-efi-amd64-signed`, `grub-pc`)

It then configures the live system, squashes it with zstd, and writes a hybrid ISO:
- **BIOS:** GRUB El Torito image.
- **UEFI:** Ubuntu's signed `shimx64.efi` → signed `gcdx64.efi` (Secure Boot capable) in an appended EFI system partition.

The mmdebstrap log is kept in `build/logs/iso-mmdebstrap.log`.

## 4. Test it

See [testing.md](testing.md).

## Changing a package

```sh
# edit files in src/<repo>, then:
source scripts/lib-commit.sh
commit_pkg <repo> "What changed"   # commits on branch remastered, adds a +remasteredN
                                   # changelog entry, re-exports patches/<repo>/
scripts/build-debs.sh <repo>
```
