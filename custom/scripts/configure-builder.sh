#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
pacman -Syu --needed --noconfirm archlinux-keyring base-devel git jq sudo python gnupg arch-install-scripts rsync
pacman-key --init
pacman-key --add .github/keys/pond-repository.asc
pacman-key --lsign-key B14C6E33AD2B9746842FFD245E3D63FCAA540F08
if ! pacman-conf --repo-list | grep -qx pond; then
  printf '\n[pond]\nSigLevel = Required\nServer = https://repo.butterfly.so/x86_64\n' >> /etc/pacman.conf
fi
pacman -Syu --noconfirm
id builder &>/dev/null || useradd -m builder
printf 'builder ALL=(root) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/pond-builder
chmod 440 /etc/sudoers.d/pond-builder
# Bound parallelism to keep C++ compilation inside 16 GiB builders.
printf '\nMAKEFLAGS="-j%s"\nPACKAGER="cylexVEVO <pond@cylex.dog>"\n' "${BUILD_JOBS:-2}" >> /etc/makepkg.conf
sed -i '/^OPTIONS=/s/\<debug\>/!debug/g' /etc/makepkg.conf
