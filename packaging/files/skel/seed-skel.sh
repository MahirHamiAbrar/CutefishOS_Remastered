#!/bin/bash
# Seeds /etc/skel with oh-my-fish (neolambda theme) and LazyVim, so every new
# user (the live user, the installer's user, adduser) starts with them,
# offline. Runs inside the ISO chroot, which has network access.
# Usage: seed-skel.sh <lazy-lock.json or ""> <where to copy a new lock>
set -euo pipefail

# Pinned upstreams (bump deliberately).
OMF_REPO=https://github.com/oh-my-fish/oh-my-fish
OMF_COMMIT=634c94b4d5e1c0737eac2e35b75022b7ea3910c9
NEOLAMBDA_COMMIT=623f355ca450acb480f312a66fee7364d533aa53
LAZYVIM_REPO=https://github.com/LazyVim/starter
LAZYVIM_COMMIT=803bc181d7c0d6d5eeba9274d9be49b287294d99

lock=${1:-}
lock_out=${2:-}
work=$(mktemp -d)
home=$work/home
mkdir -p "$home"
export HOME=$home
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME

fetch() { # repo commit dir
    git init -q "$3"
    git -C "$3" fetch -q --depth 1 "$1" "$2"
    git -C "$3" checkout -q FETCH_HEAD
}

echo "seed-skel: oh-my-fish"
fetch "$OMF_REPO" "$OMF_COMMIT" "$work/omf"
# Default --path/--config, so conf.d/omf.fish finds OMF_PATH through $HOME.
fish "$work/omf/bin/install" --local-source="$work/omf" --noninteractive --yes
fish -c 'omf install neolambda'
git -C "$home/.local/share/omf/themes/neolambda" fetch -q --depth 1 origin "$NEOLAMBDA_COMMIT"
git -C "$home/.local/share/omf/themes/neolambda" checkout -q "$NEOLAMBDA_COMMIT"
[ "$(cat "$home/.config/omf/theme")" = neolambda ] || { echo "neolambda is not the active theme" >&2; exit 1; }

echo "seed-skel: LazyVim"
fetch "$LAZYVIM_REPO" "$LAZYVIM_COMMIT" "$home/.config/nvim"
rm -rf "$home/.config/nvim/.git"
if [ -n "$lock" ] && [ -f "$lock" ]; then
    cp "$lock" "$home/.config/nvim/lazy-lock.json"
    nvim --headless "+Lazy! restore" +qa
else
    nvim --headless "+Lazy! sync" +qa
    [ -n "$lock_out" ] && cp "$home/.config/nvim/lazy-lock.json" "$lock_out"
fi
# Treesitter parsers and Mason tools are built/downloaded on first start;
# give them one headless start here so most of them are already in place.
timeout 600 nvim --headless "+sleep 240" +qa || echo "seed-skel: nvim warm-up timed out (parsers finish on first start)"

# Mason's tools are wired up with absolute paths (symlinks into this home):
# leave them to the first start, which needs network anyway for updates.
rm -rf "$home/.local/share/nvim/mason"

# Nothing that is copied may point at the throwaway home.
seeded=("$home/.config/fish" "$home/.config/omf" "$home/.config/nvim"
        "$home/.local/share/omf" "$home/.local/share/nvim")
if grep -rIl --exclude-dir=.git "$home" "${seeded[@]}" >/dev/null; then
    echo "seed-skel: files reference $home:" >&2
    grep -rIl --exclude-dir=.git "$home" "${seeded[@]}" >&2
    exit 1
fi
if find "${seeded[@]}" -type l -lname "$home*" | grep -q .; then
    echo "seed-skel: symlinks into $home:" >&2
    find "${seeded[@]}" -type l -lname "$home*" >&2
    exit 1
fi

mkdir -p /etc/skel/.config /etc/skel/.local/share
cp -a "$home/.config/fish" "$home/.config/omf" "$home/.config/nvim" /etc/skel/.config/
cp -a "$home/.local/share/omf" "$home/.local/share/nvim" /etc/skel/.local/share/
rm -rf "$work"
echo "seed-skel: done"
