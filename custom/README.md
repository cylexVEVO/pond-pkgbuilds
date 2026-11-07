# cylexVEVO Pond image

This image keeps the upstream online installer and Pond's kernels, hardware detection,
Btrfs layout and boot integration. The target system uses pinned source archives from
`cylexVEVO/pond-interface`, `cylexVEVO/vicinae` and `cylexVEVO/package-manager`.
See `sources.lock.json` for commits and checksums. Existing package names are retained.

`pond-custom-defaults` seeds **the target's** `/etc/skel`: North for the shell and
launcher, plus `/usr/share/pond-interface/wallpaper/included/ales krivec.jpg`.
Helium is installed as `helium-browser-bin` using the attributed Arch recipe.
The SDDM/Niri session and global Vicinae service remain enabled. The extension is
installed system-wide; users do not need to import it.

## Repository authority

The rootfs builder inserts `[pond-custom]` **before all other repositories** in the
target's `/etc/pacman.conf`. Both package and database signatures are required.
The fork packages use `epoch=1`; future updates must retain this epoch.
Pacman repository order selects packages with identical names regardless of version.
No `IgnorePkg` list blocks updates from your own repository.

The public key and trusted fingerprint are installed in `/usr/share/pacman/keyrings`.
The installer populates `pond-custom` before its full system upgrade. Private keyrings
are removed from the rootfs; only public signing material ships. If the custom
repository is unavailable or has a bad signature, the upgrade fails instead of
silently using upstream replacements. Do not remove/reorder it.

`custom/tests/repository-priority.sh` exercises selection and full-upgrade behavior
with real pacman against a deliberately newer upstream test package.

## Build and release

Use a disposable **privileged Arch Linux** container or VM. The caller needs root
for `arch-chroot` and Archiso. Compilation runs as `builder`. Allow at least 16 GiB
RAM and 50 GiB free disk. The build requires internet access.

```sh
custom/scripts/configure-builder.sh
custom/tests/repository-priority.sh
custom/scripts/build-packages.sh out/packages
```

Sign in a separate environment with a dedicated keyring, unavailable during source
compilation. `custom/repository.asc` and `custom/signing-fingerprint` must match it.
Back up the private key and revocation certificate securely. Renew/rotate the key
before its expiry (2028-11-06); key rotation requires shipping updated public material.

```sh
GNUPGHOME=/secure/pond-signing custom/scripts/sign-repository.sh out/packages out/repository
custom/scripts/publish-repository.sh out/repository
custom/scripts/build-rootfs.sh out/rootfs custom/work
custom/scripts/publish-rootfs.sh out/rootfs rootfs-UNIQUE-VERSION
```

Publishing needs `gh` authenticated to `cylexVEVO/pond-pkgbuilds`.
Package files are uploaded before the database and old versions are retained.
Database/signature replacement is not atomic on GitHub Releases; a client in that
brief window can retry, and signature validation fails closed.
Rootfs releases are immutable. The archive is split into <=1900 MiB assets to fit
GitHub's 2 GiB limit. `rootfs.json` lists the ordered HTTPS URLs and the SHA-256 of
the **complete** archive; each ISO pins that manifest. No offline rootfs is embedded.

In the installer checkout:

```sh
python3 scripts/use-rootfs.py /path/to/out/rootfs/rootfs.json
make check
make iso VERSION=1.0.0
```

Changing `VERSION` only changes the ISO label. Update recipes/source locks and rebuild
the package repository and rootfs to change desktop revisions. Keep `pkgver`/`pkgrel`
monotonic within epoch 1. Do not update source commits without recalculating checksums.

The `Build custom Pond image` Actions workflow automates these steps after it is on
the default branch. It requires the dedicated armored private key in the
`POND_SIGNING_KEY` repository secret. Enter an ISO version and installer ref (prefer
a full commit SHA). Its outputs include a rootfs release, manifest and ISO artifact.
Signing runs in a separate job from compilation. Upstream bot syncs and the upstream automatic package dispatcher are disabled in
this fork; use the custom workflow for a complete release.

The build procedure is repeatable; it does not promise bit-for-bit reproducibility:
Arch/Pond repositories roll forward, and some upstream CMake dependencies are fetched
by tagged versions. Packages carry makepkg `.BUILDINFO`; the rootfs includes a full
package inventory under `/usr/share/pond-custom/`. Archive the release files and
build logs when exact historical binaries matter.

## Fresh VM acceptance

Boot the ISO with a new >=32 GiB disk, network, >=4 GiB RAM and UEFI (also test BIOS).
Complete the installer and reboot from the disk. Log in and verify:

- Niri starts Pond shell; North and the selected Ales Krivec wallpaper appear immediately.
- `systemctl --user is-active vicinae` succeeds and Mod+Space opens the forked launcher.
- The package-manager extension appears without import; its Rust bridge runs.
- `helium-browser --version` succeeds and Helium opens a page.
- The new user's files match `/etc/skel/.config/pond-interface` and Vicinae settings.
- `pacman-conf --repo-list` starts with `pond-custom`; `pacman -Si pond-shell
  pond-launcher pond-pm pond-pm-extension` reports that repository.
- After `sudo pacman -Syu`, all fork packages retain epoch 1 and the intended commits.
- Reboot once more and confirm the same session, launcher and defaults.

`custom/scripts/verify-rootfs.py MOUNTPOINT` checks structural prerequisites. It is
not a substitute for the fresh VM installation and graphical checks above.
