# icons

`cutefish-icons`: the icon themes, based on Colloid (vinceliuice/Colloid-icon-theme). Upstream is cutefishos/icons. Our changes are alias icons for names that Cutefish apps use but the set lacks:
- `file-system-manager`, `cutefish-calculator`, `cutefish-screenshot` and `default-user`;
- `chevron-up` and `chevron-down`, for Terminal's find bar.

## Themes

The source is a single set (`src/`). `cmake/install-theme.cmake.in` (run by `cmake --install`) turns it into three installed themes under `/usr/share/icons/`:

| Theme | What it is |
|---|---|
| `Cutefish` | The source set as is |
| `Cutefish-Light` | Light variant |
| `Cutefish-Dark` | Dark variant. The symbolic and small (16–32 px) icons are recoloured from `#363636` to `#dedede` with `sed` at install time, and `dark/` adds dark-only icons (`user-trash`, `network-server`). |

`links/` holds symlink aliases (one name pointing to another), copied into each variant. The themes inherit `hicolor` and `breeze` for anything missing.

Which variant is used: the Qt platform theme picks `Cutefish-Light` or `Cutefish-Dark` from dark mode whenever `IconTheme` is `Cutefish` ([qt-plugins.md](qt-plugins.md)). FishUI's `image://icontheme/<name>` resolves through the same Qt icon theme.

## Layout

```
src/index.theme      theme definition (directories, sizes, contexts); Name= is rewritten per variant
src/<context>/<size>/*.svg   actions, apps, categories, devices, emblems, mimetypes, places, status
                     sizes 16, 22, 24, 32, scalable, symbolic
links/<context>/…    alias symlinks
dark/                dark-only replacements (installed into Cutefish-Dark/places/scalable)
cmake/install-theme.cmake.in   the install logic above
```

## Adding an icon or alias

- **A new icon:** put the SVG in `src/<context>/<size>/`, in the directories `index.theme` lists for that context.
- **An alias:** add a relative symlink (`ln -s go-up.svg chevron-up.svg`) in each size directory that has the target, as the chevron commit did.
- **Dark variants:** mind the recolour. Only `#363636` is replaced, so new symbolic icons should use exactly that colour.
- **Checking:** after installing (the package trigger refreshes the icon cache), open a Cutefish app that shows the name. From a shell, `find /usr/share/icons/Cutefish-Dark -name '<name>.svg'` shows whether each variant got it.
