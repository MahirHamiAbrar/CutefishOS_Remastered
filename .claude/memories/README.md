# Project memory: Cutefish OS Remastered

These notes give an agent new to this repository what earlier sessions (humans
and Claude agents) did, decided, broke, fixed and left open. Read this file
first, then the others as you need them. Last updated: 2026-09-27, session 7.

| File | What it holds |
|---|---|
| [overview.md](overview.md) | The goal, the user's requirements and decisions, the architecture in one page |
| [status.md](status.md) | What is done, what is tested (and how), what isn't, what is left |
| [timeline.md](timeline.md) | Session-by-session history: what happened, in order, including incidents |
| [workflow.md](workflow.md) | How to build, test and commit here: exact commands, harness tricks, versions |
| [pitfalls.md](pitfalls.md) | Traps that cost time before: environment, tooling, packaging, KWin, Calamares |
| [user.md](user.md) | Who the user is, their rules and preferences, decisions they made |
| [costs.md](costs.md) | What the work cost in time and machine resources |
| [next-steps.md](next-steps.md) | What to do next, in priority order, including on real hardware |

The full technical record is in `docs/`. `docs/setbacks.md` (§1–30) is the
incident log: symptom, cause, fix. `docs/testing.md` has every test result.
These memory files summarise and point there; when they disagree, the code
and `docs/` win.

## The ten things most worth knowing
1. **Upstream Cutefish is alive again** (revived Aug–Sep 2026, Qt 6.10/KF6, Wayland-only). We build on it, pinned in `repos.lock`, with our changes as `patches/<repo>/*.patch`. `src/` is **not in git**; `scripts/fetch.sh` recreates it. Never `git add src/`.
2. We ship **our own KWin** (Ubuntu 4:6.6.6 + backport of per-output virtual desktops MR !8602), version `4:6.6.6-0ubuntu0.1+cutefish3`. Blur is **not** a KWin patch any more: it's our effect `cutefish_blur` in `cutefish-kwin-plugins` (user's wish: modular changes).
3. Heavy compiles run on **Modal** (profile `mhabrarmts2`, a Modal *Function*, never a Sandbox); the **ISO** builds locally in privileged Docker (Docker Desktop).
4. **Docker Desktop and a running VirtualBox VM can't coexist** (both need VT-x). Stop the VM before `build-iso.sh`, and stop Docker before booting a VM.
5. The deliverable exists: `build/cutefish-os-26.04-amd64.iso` (final: sha256 `e7b866a3…0950e`) + debs in `build/repo/`. Both are gitignored, local to the user's laptop.
6. Everything in the test plan passes in VirtualBox on UEFI **and** BIOS, including install to disk and the installed system. Only real-hardware checks remain (`docs/hardware-checklist.md`).
7. The user wants: stay inside the repo folder; **ask, don't assume** on choices that are theirs; document every setback; commit and push often.
8. OpenSnitch `DefaultAction` stays **allow** (user's decision); the "connections pass while a prompt is open" gap is documented, not fixed.
9. The user plans to run a Claude agent **inside the installed Cutefish OS** next. If that's you, see next-steps.md, "If you're running inside Cutefish OS".
10. Test changes by booting the live ISO in the VM and `dpkg -i`-ing the debs (user's standard since session 7); `ydotool` gives the agent a mouse (workflow.md).
11. Never `pkill -f <pattern>` if the pattern appears in your own command line: it kills your own shell. Same trap with `pgrep -f` in wait loops.
