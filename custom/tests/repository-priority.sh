#!/usr/bin/env bash
# Exercise libalpm's repository selection with a much newer upstream package.
set -euo pipefail
[[ $EUID == 0 ]]
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/"{custom,upstream,root,var/lib/pacman}
for repo in custom upstream; do
  version=1.0-1
  [[ $repo == custom ]] || version=9999.0-99
  mkdir "$work/$repo/package"
  printf 'pkgname = pond-priority-probe\npkgver = %s\npkgdesc = priority test\narch = any\nsize = 0\n' "$version" > "$work/$repo/package/.PKGINFO"
  bsdtar -czf "$work/$repo/pond-priority-probe-$version-any.pkg.tar.gz" -C "$work/$repo/package" .PKGINFO
  repo-add "$work/$repo/$repo.db.tar.gz" "$work/$repo/"*.pkg.tar.gz >/dev/null
 done
cat > "$work/pacman.conf" <<CONF
[options]
Architecture = auto
SigLevel = Never
DBPath = $work/var/lib/pacman
LogFile = $work/pacman.log
[custom]
Server = file://$work/custom
[upstream]
Server = file://$work/upstream
CONF
pacman --config "$work/pacman.conf" --root "$work/root" -Sy --noconfirm >/dev/null
selected=$(pacman --config "$work/pacman.conf" --root "$work/root" -Sp --print-format '%r %v' pond-priority-probe)
[[ $selected == 'custom 1.0-1' ]]
pacman --config "$work/pacman.conf" --root "$work/root" -S --noconfirm pond-priority-probe >/dev/null
updates=$(pacman --config "$work/pacman.conf" --root "$work/root" -Sup --print-format '%r %n %v')
[[ $updates != *upstream* ]]
echo 'Repository priority survives a full upgrade with a newer upstream version'
