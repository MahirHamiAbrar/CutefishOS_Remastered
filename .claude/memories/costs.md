# What it cost

No money figures were measured; don't invent them. Check the Modal dashboard (`https://modal.com/apps/mhabrarmts2`) for real spend. What is known:

## Time (wall clock)
- The whole project so far: about 2 calendar days (2026-09-25 → 2026-09-26) across 5 agent sessions, about 40 commits on `main`.
- One Modal build on 16 CPUs / 32 GiB:
  - KWin: ~15–20 min;
  - settings or core: ~1.5–5 min;
  - meta: ~1–2 min;
  - image and mount upload: ~30 s.
- Local ISO build (`build-iso.sh`, privileged Docker Desktop): ~20–25 min (mmdebstrap alone ~12 min).
- Fresh VM boot to desktop: ~30–60 s. Calamares install in the VM: ~3–4 min.
- Session 5 alone: 2 debug KWin rebuilds to find the blur bug, 5 ISO builds, 3 install runs.

## Machine resources
- Docker Desktop's VM (~4 GB RAM) is too small for KWin: it was OOM-killed and thrashed. That's why compiles moved to Modal.
- `build/` holds about 30 GB at peak (rootfs, squashfs, ISO, VM disks: two 30 GB dynamic VDIs, a few GB used each).
- The ISO is 1.9 GB.

## Cost of mistakes (lessons)
- **About an hour** went to the blur bug: two extra KWin debug builds, plus a wedged VM after `loginctl terminate-user` and a reset that lost the live state.
- Each packaging bug found only after the ISO build cost another 25-minute ISO rebuild. Patch the live system to test first (as in session 5), then rebuild the ISO once.
- The `pkill -f` self-kill and the `pgrep -f` wait loops cost restarts and stuck background tasks.
