---
name: linux-iso-build-and-debug
description: Linux ISO Build and Debug. How to change, build, test and debug the Cutefish OS Remastered distribution (Ubuntu 26.04, Qt6/QML desktop, our own KWin, live/installer ISO) and similar Debian-based ISO projects. Use when building packages or the ISO (build-all.sh, Modal, Docker), trying a change in the VirtualBox VM, clicking through the desktop with ydotool, taking and reading VM screenshots, or debugging a desktop, session, KWin, QML, polkit, installer or boot problem.
---

# Linux ISO Build and Debug

The working method behind every Cutefish OS Remastered session: change a package, build it, install it into the booted live ISO, **drive the real desktop** (mouse, keyboard, screenshots), **verify the system state behind the pixels**, fix the root cause, and write down what happened. The ISO is rebuilt once at the end, not per change.

Before anything else, read `.claude/memories/README.md` (the project memory), then `status.md` and `next-steps.md`. The memory and `docs/` are the source of truth; this skill is the method. When they disagree, the code and `docs/` win.

## Hard rules (the user's)
- Stay inside the repo folder. VirtualBox's registry (`~/.config/VirtualBox`) is the only exception.
- **Ask, don't assume**, on choices that are the user's: behavior or security trade-offs, anything irreversible, anything outside the repo. Don't ask what you can check yourself.
- **Never `git add src/`.** `src/` is recreated by `scripts/fetch.sh`; our changes live as `patches/<repo>/*.patch`.
- Modal: a **Function**, never a Sandbox; profile `mhabrarmts2`; always `--detach`.
- Commit and push often. Log every setback in `docs/setbacks.md` (symptom / cause / fix), every result in `docs/testing.md`, every open limit in `docs/known-issues.md`, and update `.claude/memories/{status,timeline,next-steps}.md` when a piece of work ends.
- Don't leave background jobs (cron, monitors, watch loops) running when the work is done.

## The loop

1. **Understand first.** Read the code the bug goes through end to end: QML, then C++ backend, then D-Bus service, then polkit/system daemon, then config file. A report names a symptom; several "broken pages" often share one cause (setback §38: one GridView height formula broke Background and Mouse).
2. **Change** in `src/<repo>`, then `source scripts/lib-commit.sh; commit_pkg <repo> "msg"` (bumps `+remasteredN`, re-exports `patches/<repo>`); `amend_pkg <repo>` folds in follow-ups. KWin, `netmonitor/` and `packaging/` have their own flows (`.claude/memories/workflow.md`).
3. **Build** only the changed packages:
   - `scripts/build-all.sh --modal --pkgs "settings core" --skip iso,vm` (Modal, 16 CPUs), or
   - without `--modal` to build locally in Docker (KWin can OOM there).

   Debs land in `build/repo/`.
4. **Try it in the live ISO, not a new ISO.**
   - `scripts/build-all.sh --skip build,iso` boots the current ISO live in `cutefish-efi` and waits for the desktop.
   - Then `scripts/vm.sh install-debs efi build/repo/<pkg>_<ver>_amd64.deb …` installs them and restarts the session.

   The live system is RAM-only: a reboot forgets the debs, so use a session restart, not a reboot.
5. **Drive the desktop.**
   - `vm.sh mouse efi` (ydotool once per boot, flat acceleration once per session start);
   - `vm.sh app efi cutefish-settings -m <page>`;
   - `vm.sh click efi X Y`;
   - `vm.sh shot efi <name>`, then **Read the PNG** and look at it: layout, overlap, whether the toggle flipped, how strong the blur looks.

   Screenshots don't show the pointer (`vm.sh cursor efi`).
6. **Verify state, not pixels.** A page can look right while nothing was saved. For every fix, check the effect where it lands:

   | What | How |
   |---|---|
   | Config written | `vm.sh run efi cat ~/.config/kwinrc` (or `cutefishos/*.conf`) |
   | Effect loaded | `busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects isEffectLoaded s cutefish_blur` |
   | Window/compositor state | `vm.sh kwin efi 'workspace.activeWindow.resourceClass'` |
   | Account data | `busctl call org.freedesktop.Accounts …` (RealName, IconFile) |
   | Time zone | `timedatectl` |
   | Notifications | `notify-send -a <app>` and look |
   | Errors | `journalctl --user -b \| grep -iE 'qml\|warning\|error'`, `journalctl -b` for system services |

7. **Root cause, then re-verify** on the rebuilt package, not only on the hand-patched one. Recheck neighbours of the fix (other pages using the same control, other callers of the function).
8. **Record it**: `docs/testing.md` (a table per session), `docs/setbacks.md`, memory files. Commit and push the patches and docs.
9. **Ship**: `scripts/build-all.sh` (build, ISO, live boot), or `--vm-install` to also install to a fresh disk with Calamares and log in. Which apps go in the ISO is `iso-packages.yml`.

## Debugging method
- **Reproduce in the VM before theorising.** Clicking the real UI found bugs that static reading missed: a Switch 0 px tall, a Mouse page that reset the pointer speed on open, and `pkexec` not installed at all.
- **Read the journal first.** Most "nothing happens" bugs log something: polkit "Not authorized", QML `TypeError`, `symbol lookup error`, a crash-restart loop.
- **Silent no-ops have a short list of usual causes**, so check them in this order:
  1. a missing runtime dependency (the binary isn't installed);
  2. polkit refusing without asking (the interactive flag isn't set, or the caller isn't in the session);
  3. a stale config cache (`reparseConfiguration()`);
  4. a write in `onValueChanged` that fires with the initial value;
  5. a control with zero size.
- **When stuck, build with temporary logging** (`qCWarning`) rather than guessing. Two debug KWin builds found the `opacity²` blur fade (§23). Remove the logging afterwards.
- **Compare with a known-good state**: a stock setting, the previous package version, another page that works.
- **Recover, don't wedge.**
  - A broken KWin plugin loops SDDM: move the `.so` away in the guest and `sudo systemctl restart sddm`.
  - Restart a session with `systemctl restart sddm`, **never** `loginctl terminate-user` (it froze the guest).
  - If guest control dies, a VM reset loses the live state; reinstall the debs.
- **Write the setback while it's fresh**: symptom, cause, fix, and the lesson (a new pitfall).

## References
- `reference/harness.md`: every build and VM command. It covers build-all.sh, vm.sh subcommands, guest control, AppRuntime, keyboard scancodes, KWin-script queries, Calamares by keyboard, and the Docker/VirtualBox switch.
- `reference/pitfalls.md`: traps that already cost hours: tooling, host, Modal, packaging, KWin/Qt/QML, polkit, installer, boot.
- Project memory: `.claude/memories/` (status, timeline, workflow, pitfalls, user, costs, next-steps); full incident log: `docs/setbacks.md`; tests: `docs/testing.md`.
