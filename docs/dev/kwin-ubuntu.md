# kwin-ubuntu

Our KWin: Ubuntu 26.04's `kwin` source package (`4:6.6.6-0ubuntu0.1`) plus two sets of patches, built as `…+cutefish2`. It is the Wayland compositor and window manager of the session. Every package `kwin` builds (`kwin-wayland`, `kwin-common`, `kwin-data`, `libkwin6`, `kwin-dev`) is replaced by ours. API reference, limited to the files our patches touch: [api/kwin-ubuntu.md](api/kwin-ubuntu.md).

## What we change

| Patch set | Files (main ones) | What it does | Docs |
|---|---|---|---|
| `cutefish-per-output-0001…0007` | `src/virtualdesktops.{h,cpp}`, `workspace.*`, `window.*`, `x11window.cpp`, `xdgshellwindow.cpp`, `wayland/plasmavirtualdesktop.*`, `wayland/org-kde-plasma-virtual-desktop.xml`, `scripting/workspace_wrapper.*`, `effect/` QuickSceneView, desktop-change OSD, tests | Backport of KWin MR !8602 (Plasma 6.7): each output has its own current virtual desktop. Enabled by `[Windows] PerOutputVirtualDesktops=true`. | [../multi-display.md](../multi-display.md) |
| `cutefish-blur-0001`, `0002` | `src/plugins/blur/blur.{h,cpp}`, `blur.kcfg` | `ForceBlurClasses`: blur the whole window of listed apps that don't request blur themselves, at full blur strength. Only normal windows qualify. A class matches the resource name or the resource class, case-insensitively (`isForceBlurred`) | [../blur.md](../blur.md) |

The patches live in `patches/kwin/`, which is the source of truth. The kwin-plugins package depends on this exact KWin (`kwin-wayland (>= 4:6.6.6-0ubuntu0.1+cutefish1)`), and its effect compiles against our `kwin-dev` ([kwin-plugins.md](kwin-plugins.md)).

## How the tree is made

`src/kwin-ubuntu` is **not** an upstream git checkout. `scripts/fetch.sh` builds it when it is missing:
1. runs `apt-get source kwin=4:6.6.6-0ubuntu0.1` in the builder image, then `dpkg-source -x`;
2. makes a local git repository ("ubuntu kwin …");
3. runs `git am patches/kwin/*.patch`;
4. copies the patches into `debian/patches/`, appends them to `debian/patches/series` and `.pc/applied-patches` (the tree is already patched, and quilt must know that);
5. prepends a `+cutefish2` changelog entry.

`commit_pkg` doesn't apply here, because the repository isn't in `repos.lock`.

## Changing KWin

1. Edit in `src/kwin-ubuntu` and commit there.
2. Export the commit: `git -C src/kwin-ubuntu format-patch -1 HEAD -o /tmp/p`, then rename it to `patches/kwin/cutefish-<topic>-NNNN-<subject>.patch`. The glob order is the apply order.
3. Register it in the tree, as `fetch.sh` would:
   - copy it to `debian/patches/`;
   - append its name to `debian/patches/series` and `.pc/applied-patches`;
   - add a changelog entry, bumping `+cutefishN`;
   - commit.
4. Update `fetch.sh` so a fresh fetch reproduces the result: its changelog block (the version and one line per patch set).
5. Build: `modal run scripts/modal_build.py --pkgs "kwin kwin-plugins"`. KWin takes about 20 minutes on Modal and hours in a small Docker VM. Always rebuild kwin-plugins with it, because its effect uses KWin's internal API.
6. Test in the VM:
   - install every KWin deb together;
   - restart SDDM;
   - check `loadedEffects`, and the behaviour you changed. For multiple displays, see `scripts/test-spaces.sh`.

## Moving to a newer Ubuntu KWin

Ubuntu will publish `0ubuntu0.2` and later with security fixes. To follow:
1. set `KWIN_VERSION` in `scripts/fetch.sh`;
2. delete `src/kwin-ubuntu`;
3. run `scripts/fetch.sh`;
4. fix any patch that no longer applies.

Two known risks:
- **`apt-get source` needs the exact version in the archive.** Once Ubuntu supersedes `0ubuntu0.1`, `fetch.sh` can't recreate this tree. Keep a copy of `build/kwin-src/`. Calamares' fetch already falls back to Launchpad, which keeps every version, and the same could be done here.
- **Ubuntu's newer KWin would win at ISO build time.** `scripts/build-iso.sh` pins `*+cutefish*` versions to priority 1001 during the bootstrap and fails if `kwin-wayland` isn't ours. On an installed system, `apt upgrade` would still replace our KWin with a newer Ubuntu one, so rebuild ours on every Ubuntu KWin update.
