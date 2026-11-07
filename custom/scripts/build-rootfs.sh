#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
[[ $EUID == 0 ]] || { echo 'Root privileges and an Arch environment are required' >&2; exit 1; }
output=$(realpath -m "${1:-out/rootfs}")
work=$(realpath -m "${2:-custom/work}")
install -d "$output" "$work"
root="$work/rootfs"
# Refuse to reuse a partially configured target; remove only the dedicated work tree yourself.
[[ ! -e $root ]] || { echo "$root already exists; choose a fresh work directory" >&2; exit 1; }
url=$(jq -r .upstream_rootfs.url custom/profile.json)
checksum=$(jq -r .upstream_rootfs.sha256 custom/profile.json)
archive=${UPSTREAM_ROOTFS:-$work/upstream-rootfs.tar.zst}
if [[ ! -f $archive ]]; then
  curl --fail --location --proto '=https' --retry 3 --remove-on-error "$url" -o "$archive"
fi
printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -
install -d "$root"
bsdtar --numeric-owner --acls --xattrs -xpf "$archive" -C "$root"
# Never ship any build-host DNS configuration.
cp -a --no-dereference "$root/etc/resolv.conf" "$work/resolv.conf.original"
rm -f "$root/etc/resolv.conf"
cp -L /etc/resolv.conf "$root/etc/resolv.conf"
restore_dns() {
  rm -f "$root/etc/resolv.conf"
  cp -a --no-dereference "$work/resolv.conf.original" "$root/etc/resolv.conf"
}
# pacman CheckSpace needs a mountpoint at the chroot root.
mount --bind "$root" "$root"
cleanup() {
  restore_dns
  umount "$root"
}
trap cleanup EXIT
fingerprint=$(<custom/signing-fingerprint)
keyring="$root/usr/share/pacman/keyrings"
install -d "$keyring"
gpg --batch --dearmor < custom/repository.asc > "$keyring/pond-custom.gpg"
printf '%s:4:\n' "$fingerprint" > "$keyring/pond-custom-trusted"
: > "$keyring/pond-custom-revoked"
# Insert the custom repository before ALL other repositories, in the TARGET.
python3 - "$root/etc/pacman.conf" custom/profile.json <<'PY'
import json,re,sys
from pathlib import Path
path=Path(sys.argv[1]); profile=json.loads(Path(sys.argv[2]).read_text())
text=path.read_text()
match=next(m for m in re.finditer(r'^\[([^]]+)\]',text,re.M) if m[1]!='options')
entry=f'[{profile["repository"]}]\nSigLevel = Required DatabaseRequired\nServer = {profile["server"]}\n\n'
path.write_text(text[:match.start()]+entry+text[match.start():])
PY
arch-chroot "$root" pacman-key --init
arch-chroot "$root" pacman-key --populate archlinux pond pond-custom
mapfile -t packages < <(jq -r '.packages[]' custom/profile.json)
arch-chroot "$root" pacman -Syu --noconfirm --needed "${packages[@]/#/pond-custom/}"
# Confirm every replacement resolves to our repository before and after an upgrade.
first=$(arch-chroot "$root" pacman-conf --repo-list | head -1)
[[ $first == pond-custom ]]
for package in "${packages[@]}"; do
  [[ $(arch-chroot "$root" pacman -Si "$package" | awk '/^Repository/{print $3;exit}') == pond-custom ]]
done
arch-chroot "$root" pacman -Syu --noconfirm
while IFS= read -r service; do arch-chroot "$root" systemctl enable "$service"; done < <(jq -r '.services[]' custom/profile.json)
arch-chroot "$root" systemctl --global enable vicinae.service
install -d "$root/var/lib/sddm"
printf '[Last]\nSession=/usr/share/wayland-sessions/%s.desktop\n' "$(jq -r .session custom/profile.json)" > "$root/var/lib/sddm/state.conf"
arch-chroot "$root" chown -R sddm:sddm /var/lib/sddm
# Record exactly what went into this rootfs; retain upstream kernel/hardware/boot files.
install -d "$root/usr/share/pond-custom"
cp custom/{profile.json,sources.lock.json,signing-fingerprint} "$root/usr/share/pond-custom/"
arch-chroot "$root" pacman -Q > "$root/usr/share/pond-custom/packages.txt"
python3 custom/scripts/verify-rootfs.py "$root"
# Exercise the installer's actual home-creation mechanism before sealing the image.
arch-chroot "$root" useradd -m pond-defaults-check
cmp "$root/etc/skel/.config/pond-interface/theme.json" "$root/home/pond-defaults-check/.config/pond-interface/theme.json"
cmp "$root/etc/skel/.config/pond-interface/wallpaper.json" "$root/home/pond-defaults-check/.config/pond-interface/wallpaper.json"
cmp "$root/etc/skel/.config/vicinae/settings.json" "$root/home/pond-defaults-check/.config/vicinae/settings.json"
arch-chroot "$root" userdel -r pond-defaults-check
cp "$root/usr/share/pond-custom/packages.txt" "$output/packages.txt"
# Fresh installation identity; no builder user, credentials, or pacman private keyring.
rm -f "$root/etc/machine-id" "$root/var/lib/dbus/machine-id" "$root/var/lib/systemd/random-seed"
: > "$root/etc/machine-id"
arch-chroot "$root" gpgconf --homedir /etc/pacman.d/gnupg --kill all || true
rm -rf "$root/etc/pacman.d/gnupg" "$root/var/cache/pacman/pkg/"* "$root/var/log/journal/"*
restore_dns
umount "$root"
trap - EXIT
bsdtar --numeric-owner --acls --xattrs -cpf - -C "$root" . | zstd -T2 -15 -o "$output/pond-rootfs.tar.zst"
(cd "$output" && sha256sum pond-rootfs.tar.zst > pond-rootfs.tar.zst.sha256)
