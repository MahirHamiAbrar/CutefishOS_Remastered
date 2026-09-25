# Ubuntu 26.04 build environment for Cutefish debs and the ISO.
FROM ubuntu:26.04
ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential devscripts equivs debhelper lintian fakeroot git ca-certificates \
      cmake extra-cmake-modules pkg-config dpkg-dev apt-utils \
      mmdebstrap squashfs-tools xorriso mtools dosfstools grub-pc-bin grub-efi-amd64-bin \
      grub-efi-amd64-signed shim-signed curl gnupg \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /ws
