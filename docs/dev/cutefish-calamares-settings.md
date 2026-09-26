# cutefish-calamares-settings

The installer settings from the **old** CutefishOS (the `cutefishos-ubuntu` fork). It's a packaged tree (`DEBIAN/`, `etc/calamares/…`, `usr/…`) for Ubuntu 21.04's Calamares, fetched from `cutefishos-ubuntu/cutefish-calamares-settings` (`LEGACY` in `scripts/fetch.sh`).

**It is not built or shipped.** It is kept only as a reference. The installer configuration we ship is `calamares-settings-cutefish`, built from `packaging/calamares/` in this repository and derived from Kubuntu 26.04's settings ([calamares-ubuntu.md](calamares-ubuntu.md), [../building.md](../building.md)).

Its contents:
- `etc/calamares/settings.conf`: the module sequence;
- `etc/calamares/modules/*.conf`: per-module settings;
- `etc/calamares/branding/cutefish/`: branding (`branding.desc`, the `show.qml` slideshow);
- `usr/lib/…/calamares/modules/automirror/`: a Python module that picks an Ubuntu mirror near the user;
- `usr/bin/calamares-logs-helper`: copies the installer log into the installed system.

The pieces still useful (branding, the logs helper, the `automirror` settings) have already been carried over into `packaging/calamares/`. If you need something else from here, copy it into `packaging/calamares/` and adapt it to Calamares 3.3 and Kubuntu's module layout. Don't build this tree.
