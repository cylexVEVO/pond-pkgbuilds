#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
[[ $EUID == 0 ]] || { echo 'Run inside an Arch builder as root' >&2; exit 1; }
output=$(realpath -m "${1:-out/packages}")
install -d -o builder -g builder "$output"
export CMAKE_BUILD_PARALLEL_LEVEL=${BUILD_JOBS:-2}
# Each recipe is built as an unprivileged user, then installed for later dependencies.
# Do not give the build user access to the repository signing key.
while IFS= read -r recipe; do
  [[ -n $recipe && $recipe != \#* ]] || continue
  [[ $recipe =~ ^[a-z0-9/-]+$ && -f $recipe/PKGBUILD ]]
  if [[ ${RESUME_BUILD:-0} == 1 && -f $output/${recipe##*/}/manifest-${recipe##*/}.json ]]; then
    echo "Reusing $recipe"
  else
    chown -R builder:builder "$recipe"
    sudo -u builder -H --preserve-env=CMAKE_BUILD_PARALLEL_LEVEL \
      .github/scripts/build-package.sh "$recipe" "$output/${recipe##*/}"
  fi
  pacman -U --noconfirm "$output/${recipe##*/}/"*.pkg.tar.zst
 done < custom/packages.txt
