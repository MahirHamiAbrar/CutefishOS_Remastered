# calamares-ubuntu

Our Calamares, the live ISO's installer: Ubuntu 26.04's `calamares` source package (`3.3.14-0ubuntu25`) plus our patches, built as `3.3.14-0ubuntu25+cutefish1`. The installer's *configuration* (branding, module list, module settings) is not here: it is `calamares-settings-cutefish`, built from `packaging/calamares/` in this repository and derived from Kubuntu's settings.

## What we change

| Patch | File | What it does |
|---|---|---|
| `patches/calamares/cutefish-0001-locale-time-zone-does-not-pick-language-or-formats.patch` | `src/modules/locale/Config.cpp` (`automaticLocaleConfiguration`) | The formats locale (numbers, dates, currency) used to follow the selected time zone's country, so an English install in Asia/Dhaka got `bn_BD` formats. Now the country comes from the chosen language (`en_US` gives `US`). The time zone only sets the clock; the language and the formats change only when the user picks them on the Location page. |

Two build-configuration changes are made by `scripts/fetch.sh` in `debian/rules`, not by a patch:
- `-DPython_EXECUTABLE=/usr/bin/python3`;
- `-DBUILD_TESTING=OFF`.

Setback 34 explains why. `scripts/build-in-container.sh` also gives builds a system-only `PATH` and checks that the package contains `/usr/bin/calamares`.

`calamares-settings-cutefish` depends on `calamares (>= 3.3.14-0ubuntu25+cutefish1)`. `scripts/build-iso.sh` pins the `+cutefish` versions of the `calamares*`, `kwin*` and `libkwin*` packages during the bootstrap and fails if the ISO's `calamares` isn't ours, so a newer Ubuntu revision can't silently replace it.

## How the tree is made

`src/calamares-ubuntu` is a local git repository, built by `scripts/fetch.sh` when it is missing:
1. downloads the `.dsc`, `.orig.tar.gz` and `.debian.tar.xz` from Ubuntu's archive pool, or from Launchpad (`launchpad.net/ubuntu/+archive/primary/+sourcefiles/calamares/<version>/…`), which keeps superseded versions too;
2. runs `dpkg-source -x`, which checks the files against the `.dsc`;
3. runs `git init`, then `git am patches/calamares/*.patch`;
4. edits `debian/rules` as above;
5. registers the patches in `debian/patches/series` and `.pc/applied-patches`;
6. prepends the `+cutefish1` changelog entry.

`commit_pkg` doesn't apply here, because the repository isn't in `repos.lock`.

## Where things are in Calamares

```
src/calamares/         the application (main window, view manager)
src/libcalamares/      core library: job queue, global storage, locale data, Python bindings (boost::python)
src/libcalamaresui/    UI library: module loading, view steps, branding
src/modules/<name>/    one module each; C++ view modules (locale, keyboard, users, partition, …) and
                       Python job modules (unpackfs, bootloader, fstab, …: main.py + module.desc)
src/branding/          default branding (ours is in packaging/calamares/branding/cutefish)
lang/                  translations
```

Each module has a `Config` (the state and logic, exposed to QML or widgets), a `ViewStep` (the page) and jobs (`exec()` at install time). Values pass between modules through `GlobalStorage` (for example `localeConf`, which the `localecfg` job writes to `/etc/default/locale`).

## Changing Calamares

1. Edit in `src/calamares-ubuntu` and commit there.
2. Export the commit: `git -C src/calamares-ubuntu format-patch -1 HEAD`, named `patches/calamares/cutefish-NNNN-<subject>.patch`.
3. Register it:
   - copy it to `debian/patches/`;
   - append its name to `series` and `.pc/applied-patches`;
   - bump `+cutefishN` in the changelog;
   - commit.
4. Update `scripts/fetch.sh`'s changelog block, so a fresh fetch reproduces the result.
5. Raise the `calamares (>= …)` dependency in `packaging/debian/control` if the settings rely on the change.
6. Build: `modal run scripts/modal_build.py --pkgs "calamares meta"` (about 10 minutes on Modal).
7. Test: build the ISO, boot it and run the installer. `build/vm/cal-drive.sh <downs>` (gitignored, see [../testing.md](../testing.md)) drives it by keyboard; the installer log is `~/.cache/calamares/session.log` in the live session.

Most installer behaviour is configuration, not code. Before patching, check whether a module's `.conf` in `packaging/calamares/modules/` can do it; an entry there overrides the one from `calamares-settings-ubuntu-common`.

## Moving to a newer Ubuntu Calamares

1. Set `CALAMARES_VERSION` in `scripts/fetch.sh`.
2. Delete `src/calamares-ubuntu`.
3. Run `scripts/fetch.sh`, and refresh any patch that no longer applies.
4. Check that the `sed` on `debian/rules` still matches; `fetch.sh` doesn't fail if it doesn't. `grep BUILD_TESTING=OFF src/calamares-ubuntu/debian/rules` shows whether it did.
5. Keep the version in `packaging/debian/control` in step.
