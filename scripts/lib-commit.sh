# Source this, then: commit_pkg <repo-under-src> "<message>"
# Commits the working tree of src/<repo> on the `remastered` branch, adds a
# changelog entry (+remasteredN, bumped once per commit) and re-exports patches/<repo>/.
commit_pkg() {
    local repo=$1 msg=$2
    (
        cd "$(dirname "${BASH_SOURCE[0]}")/../src/$repo" || exit 1
        local src ver base n
        src=$(sed -n '1s/ .*//p' debian/changelog)
        ver=$(sed -n '1s/.*(\(.*\)).*/\1/p' debian/changelog)
        if [[ $ver =~ ^(.*)\+remastered([0-9]+)$ ]]; then
            base=${BASH_REMATCH[1]}; n=$((BASH_REMATCH[2] + 1))
        else
            base=${ver%-*}; n=1
        fi
        printf '%s (%s+remastered%s) resolute; urgency=medium\n\n  * %s\n\n -- Cutefish Remastered <remastered@localhost>  %s\n\n' \
            "$src" "$base" "$n" "$msg" "$(date -R)" | cat - debian/changelog > debian/changelog.new
        mv debian/changelog.new debian/changelog
        git add -A
        git -c user.name=remastered -c user.email=remastered@localhost commit -qm "$msg"
        local pinned
        pinned=$(awk -v n="$repo" '$1 == n {print $3}' ../../repos.lock)
        mkdir -p ../../patches/"$repo"
        rm -f ../../patches/"$repo"/*.patch
        git format-patch -q "$pinned"..HEAD -o ../../patches/"$repo"
        echo "$repo -> $base+remastered$n ($(ls ../../patches/"$repo" | wc -l) patches)"
    )
}

# amend_pkg <repo>: fold the working-tree changes of src/<repo> into its last
# remastered commit (for follow-up fixes) and re-export patches/<repo>/.
amend_pkg() {
    local repo=$1
    (
        cd "$(dirname "${BASH_SOURCE[0]}")/../src/$repo" || exit 1
        local base
        base=$(awk -v n="$repo" '$1 == n {print $3}' ../../repos.lock)
        git add -A
        git -c user.name=remastered -c user.email=remastered@localhost commit -q --amend --no-edit
        rm -f ../../patches/"$repo"/*.patch
        git format-patch -q "$base"..HEAD -o ../../patches/"$repo"
        echo "$repo amended"
    )
}
