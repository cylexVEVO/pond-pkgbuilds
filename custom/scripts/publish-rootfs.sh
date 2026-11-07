#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output=$(realpath "${1:-out/rootfs}")
tag=${2:?usage: publish-rootfs.sh output immutable-tag}
[[ $tag =~ ^rootfs-[A-Za-z0-9._-]+$ ]]
repo=${GH_REPO:-cylexVEVO/pond-pkgbuilds}
# Never overwrite rootfs parts at a URL already pinned by an installer ISO.
! gh release view "$tag" --repo "$repo" >/dev/null 2>&1 || { echo 'Rootfs release already exists' >&2; exit 1; }
# GitHub limits individual assets to 2 GiB; the installer streams and rejoins parts.
split -b 1900M -d "$output/pond-rootfs.tar.zst" "$output/pond-rootfs.tar.zst.part-"
python3 - "$output" "$repo" "$tag" <<'PY'
import hashlib,json,sys
from pathlib import Path
out=Path(sys.argv[1]); base=f'https://github.com/{sys.argv[2]}/releases/download/{sys.argv[3]}'
sha=(out/'pond-rootfs.tar.zst.sha256').read_text().split()[0]
manifest={'sha256':sha,'urls':[f'{base}/{p.name}' for p in sorted(out.glob('pond-rootfs.tar.zst.part-*'))]}
(out/'rootfs.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
gh release create "$tag" --repo "$repo" --target "$(git rev-parse HEAD)" \
  --title "Custom Pond $tag" --notes 'Online installer rootfs: pinned forks, Helium, North theme and Ales Krivec wallpaper.' \
  "$output/"*.part-* "$output/rootfs.json" "$output/pond-rootfs.tar.zst.sha256" "$output/packages.txt"
