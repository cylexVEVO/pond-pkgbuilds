#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
repository=${GH_REPO:-cylexVEVO/pond-pkgbuilds}
output=$(realpath "${1:-out/repository}")
# Keep old package files so clients with a cached database can still download them.
if ! gh release view repository --repo "$repository" >/dev/null 2>&1; then
  gh release create repository --repo "$repository" --target "$(git rev-parse HEAD)" \
    --title 'Signed Pond replacement packages' --notes 'Rolling signed pacman repository for cylexVEVO Pond. Older package files are retained.'
fi
shopt -s nullglob
packages=("$output/"*.pkg.tar.zst "$output/"*.pkg.tar.zst.sig)
gh release upload repository --repo "$repository" --clobber "${packages[@]}" \
  "$output/repository.asc" "$output/sources.lock.json" "$output/profile.json"
# Publish the signed database after all packages are available.
gh release upload repository --repo "$repository" --clobber \
  "$output/pond-custom.db.tar.gz" "$output/pond-custom.db.tar.gz.sig" \
  "$output/pond-custom.db" "$output/pond-custom.db.sig" \
  "$output/pond-custom.files.tar.gz" "$output/pond-custom.files.tar.gz.sig" \
  "$output/pond-custom.files" "$output/pond-custom.files.sig" \
  "$output/SHA256SUMS" "$output/SHA256SUMS.sig"
