#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${GNUPGHOME:?Use a dedicated signing keyring, outside the source/build workspace}"
input=$(realpath "${1:-out/packages}")
output=$(realpath -m "${2:-out/repository}")
[[ $output != / && $output != "$input" && $output != "$input/"* ]]
install -d "$output"
# Regenerate the database from this build only; historical packages stay on the server.
find "$output" -maxdepth 1 \( -name '*.pkg.tar.zst*' -o -name 'pond-custom.*' -o -name 'SHA256SUMS*' \) -delete
fingerprint=$(<custom/signing-fingerprint)
[[ $(gpg --batch --show-keys --with-colons custom/repository.asc | awk -F: '$1=="fpr"{print $10;exit}') == "$fingerprint" ]]
mapfile -t packages < <(find "$input" -type f -name '*.pkg.tar.zst' | sort)
((${#packages[@]} == $(grep -cv '^#\|^$' custom/packages.txt)))
for package in "${packages[@]}"; do
  install -m644 "$package" "$output/"
  gpg --batch --yes --local-user "$fingerprint" --detach-sign "$output/${package##*/}"
done
cp custom/repository.asc "$output/"
cp custom/{sources.lock.json,profile.json} "$output/"
cd "$output"
repo-add --sign --key "$fingerprint" pond-custom.db.tar.gz ./*.pkg.tar.zst
# Release hosting serves files, not symlinks. Publish explicit aliases too.
for name in pond-custom.db pond-custom.db.sig pond-custom.files pond-custom.files.sig; do
  cp --remove-destination "$(readlink "$name")" "$name"
done
sha256sum ./*.pkg.tar.zst ./*.sig ./*.asc ./*.json pond-custom.db pond-custom.db.tar.gz > SHA256SUMS
gpg --batch --yes --local-user "$fingerprint" --detach-sign SHA256SUMS
