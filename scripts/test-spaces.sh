#!/usr/bin/env bash
# Checks "Displays have separate Spaces" in the running VM: switches only the
# second display to another Space and checks that the first one stays put.
#
#   scripts/test-spaces.sh [efi|bios]
#
# KWin's D-Bus "current" Space is the one on the active output, so D-Bus alone
# can't tell per-display Spaces from global ones. A KWin script can, through
# the backport's workspace.currentDesktopForScreen(). Its result comes back as
# the name of the first Space (the only string a script can publish), which is
# restored afterwards. Display 2 is left on the other Space for the screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."
fw=${1:-efi}

scripts/vm.sh displays "$fw" 2
sleep 8

read -r -d '' GUEST <<'GUEST' || true
set -e
pid=$(pgrep -u "$(id -u)" -x kwin_wayland | head -1)
[ -n "$pid" ] || { echo "FAIL no kwin_wayland in this session"; exit 1; }
addr=$(tr '\0' '\n' 2>/dev/null < /proc/$pid/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
export DBUS_SESSION_BUS_ADDRESS=${addr:-unix:path=/run/user/$(id -u)/bus}

cat > /tmp/cutefish-spaces-test.js <<'JS'
const screens = workspace.screens;
const desktops = workspace.desktops;
let result;
if (screens.length < 2 || desktops.length < 2) {
    result = "SKIP " + screens.length + " display(s), " + desktops.length + " Space(s)";
} else {
    const first = screens[0], second = screens[1];
    const nameOf = id => desktops.find(d => d.id === id).name;
    const firstBefore = workspace.currentDesktopForScreen(first).id;
    const secondBefore = workspace.currentDesktopForScreen(second).id;
    const target = desktops.find(d => d.id !== secondBefore);
    workspace.setCurrentDesktopForScreen(target, second);
    const firstAfter = workspace.currentDesktopForScreen(first).id;
    const secondAfter = workspace.currentDesktopForScreen(second).id;
    const ok = secondAfter === target.id && firstAfter === firstBefore;
    result = (ok ? "PASS " : "FAIL ")
        + first.name + ": " + nameOf(firstBefore) + " -> " + nameOf(firstAfter) + ", "
        + second.name + ": " + nameOf(secondBefore) + " -> " + nameOf(secondAfter);
}
desktops[0].name = "spaces-test: " + result;
JS

VDM="org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager"
SCRIPTING="org.kde.KWin /Scripting org.kde.kwin.Scripting"
space() {  # space id|name: of the first Space
    busctl --user --json=short get-property $VDM desktops |
        python3 -c 'import json, sys; d = json.load(sys.stdin)["data"][0]; print(d[1] if sys.argv[1] == "id" else d[2])' "$1"
}

id=$(space id)
name=$(space name)
echo "PerOutputVirtualDesktops: $(grep -h '^PerOutputVirtualDesktops=' ~/.config/kwinrc /etc/xdg/kwinrc 2>/dev/null | head -1)"

busctl --user call $SCRIPTING unloadScript s cutefish-spaces-test >/dev/null
script=$(busctl --user call $SCRIPTING loadScript ss /tmp/cutefish-spaces-test.js cutefish-spaces-test | cut -d' ' -f2)
busctl --user call org.kde.KWin /Scripting/Script$script org.kde.kwin.Script run

result=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    now=$(space name)
    case $now in "spaces-test: "*) result=${now#spaces-test: }; break ;; esac
    sleep 0.5
done

busctl --user call $VDM setDesktopName ss "$id" "$name"
busctl --user call $SCRIPTING unloadScript s cutefish-spaces-test >/dev/null
echo "${result:-FAIL the KWin script reported nothing (see the session log for js errors)}"
case $result in PASS*) exit 0 ;; *) exit 1 ;; esac
GUEST

status=0
scripts/vm.sh run "$fw" /bin/sh -c "$GUEST" || status=$?
sleep 2
scripts/vm.sh shot "$fw" spaces-test
exit $status
