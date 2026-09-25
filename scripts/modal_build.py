"""Build the Cutefish .debs on Modal (16 cores, 32 GiB) instead of locally.

    MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py                     # everything
    MODAL_PROFILE=mhabrarmts2 .venv/bin/modal run scripts/modal_build.py --pkgs "kwin kwin-plugins"

Same steps as scripts/build-debs.sh (both run scripts/build-in-container.sh in
the image from docker/Dockerfile). The package repository lives in the Modal
volume "cutefish-build" (out/repo) so later runs can build against earlier
packages; after each run the repository and logs are copied to build/repo and
build/logs here. Compiling happens on the container's local disk.
"""

import pathlib

import modal

ROOT = pathlib.Path(__file__).resolve().parent.parent
IGNORE = ["**/.git", "**/obj-*", "**/debian/.debhelper"]

image = (
    modal.Image.from_dockerfile(str(ROOT / "docker" / "Dockerfile"), add_python="3.12")
    # gVisor lacks openat2, which GNU tar needs: see docker/openat2-shim.c.
    .add_local_file(ROOT / "docker" / "openat2-shim.c", "/usr/local/src/openat2-shim.c", copy=True)
    .run_commands("gcc -shared -fPIC -O2 -o /usr/local/lib/openat2-shim.so /usr/local/src/openat2-shim.c -ldl")
    .env({"LD_PRELOAD": "/usr/local/lib/openat2-shim.so"})
    .add_local_dir(ROOT / "src", "/ws/src", ignore=IGNORE, copy=True)
    .add_local_dir(ROOT / "netmonitor", "/ws/netmonitor", ignore=IGNORE, copy=True)
    .add_local_dir(ROOT / "packaging", "/ws/packaging", ignore=IGNORE, copy=True)
    .add_local_file(ROOT / "scripts" / "build-in-container.sh", "/ws/scripts/build-in-container.sh", copy=True)
)
volume = modal.Volume.from_name("cutefish-build", create_if_missing=True)
app = modal.App("cutefish-build", image=image)


# ponytail: 2 h cap per run as a cost guard; raise if a full rebuild ever needs more.
@app.function(cpu=16, memory=32768, timeout=2 * 60 * 60, volumes={"/vol": volume})
def build(pkgs: list[str]) -> int:
    import os
    import subprocess

    # gVisor reports the host's RAM in /proc/meminfo, so -j is set explicitly.
    env = dict(os.environ, WS="/ws", BUILD="/tmp/build", OUT="/vol/out", JOBS="16")
    result = subprocess.run(["bash", "/ws/scripts/build-in-container.sh", *pkgs], env=env)
    volume.commit()
    return result.returncode


@app.local_entrypoint()
def main(pkgs: str = ""):
    code = build.remote(pkgs.split())

    for remote_dir, local_dir in (("out/repo", "build/repo"), ("out/logs", "build/logs")):
        target = ROOT / local_dir
        target.mkdir(parents=True, exist_ok=True)
        for entry in volume.listdir(remote_dir):
            name = pathlib.PurePosixPath(entry.path).name
            with open(target / name, "wb") as f:
                for chunk in volume.read_file(entry.path):
                    f.write(chunk)
        print(f"synced {remote_dir} -> {local_dir}")

    if code:
        raise SystemExit(f"build failed (exit {code}); see build/logs/")
