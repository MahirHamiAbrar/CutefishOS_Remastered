#!/usr/bin/env bash
# Build Cutefish .debs inside the Ubuntu 26.04 builder container.
# Usage: scripts/build-debs.sh [package ...]   (default: all, in dependency order;
#        the order lives in scripts/build-in-container.sh)
# Output: build/repo/*.deb + Packages index; per-package logs in build/logs/.
#
# Sources are copied into the Docker volume "cutefish-build" and built there:
# the Docker Desktop bind mount (virtiofs) is slow and refuses the ownership
# changes `cp -a` makes in dh_install. The volume keeps each package's
# obj-* tree, so RESUME=1 continues an interrupted build (dpkg-buildpackage -nc).
# Env: JOBS=<n> parallel compile jobs (default: 1 per 1.5 GB of container RAM;
#      KWin needs ~1 GB per g++ process).
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/repo build/logs
exec docker run --rm -i -v "$PWD":/ws -v cutefish-build:/build \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e JOBS="${JOBS:-}" -e RESUME="${RESUME:-}" \
    cutefish-builder bash /ws/scripts/build-in-container.sh "$@"
