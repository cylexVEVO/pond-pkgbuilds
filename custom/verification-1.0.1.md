# Custom Pond 1.0.1 verification

Build date: 2026-11-07 UTC. Architecture: x86_64. Installer mode: online.

## Image contents and provenance

- Interface: `cylexVEVO/pond-interface` at `399b1db1b38ecd1bf5830da1733543a75c8c4b63`.
- Vicinae: `cylexVEVO/vicinae` at `89a3b808e3667431eb932740d5e8c0dba21b9582`.
- Package manager and launcher extension: `cylexVEVO/package-manager` at `f2a5f2caf7c10ee6eda1869ef5de69e59e21b0e4`.
- Helium: `0.21.1.1`, verified upstream signature and archive checksum.
- North for Pond and Vicinae; bundled `ales krivec.jpg` wallpaper.
- Existing Niri/Kitty/session defaults retained; preferred settings packaged as `pond-custom-defaults` under target `/etc/skel`.
- Dedicated repository signing fingerprint: `74DB1A9A509830AF1CCF614E2E795202F218BDA6`.

The target's `pond-custom` repository precedes Pond/Arch repositories and requires package and database signatures. Nine replacement package names remain unchanged and carry epoch 1. The rootfs includes a package inventory and source lock under `/usr/share/pond-custom`.

## Artifact checksums

- ISO SHA-256: `97982bebd8533b4ab928934cf9252974d8df103cc7158ce74610e05b920eb709`.
- Complete rootfs SHA-256: `62416c17624d47e9709a528e8ad5b1e65032283844b3cd22880458e8b9a7b51c`.
- Release: https://github.com/cylexVEVO/pond-pkgbuilds/releases/tag/rootfs-1.0.1

The first release's private signing keyring is retained at `~/.config/pond-signing`
on the build machine. Back it up securely for future updates; the public key is
in the repository and the CI private key is stored in `POND_SIGNING_KEY`.

## Build and automated checks

- All eleven package recipes built successfully as an unprivileged builder.
- Launcher: seven native suites, 391 cases and 17,819 assertions passed.
- Package-manager Rust tests: seven passed; the TypeScript extension and Rust bridge built successfully.
- Interface Python tests: 51 passed.
- Greeter native D-Bus tests: nine passed, including missing hardware/PAM, no enrollment, enrollment permission denied, switching users and changing PAM configuration.
- Installer: three tests passed for manifest validation, ordered split download/checksum verification, tamper rejection and failed-download cleanup.
- Shell syntax, ShellCheck, actionlint and whitespace checks passed.
- Pacman repository-priority test used a deliberately newer upstream version and confirmed that a full upgrade retained the first repository's replacement.
- Actual hosted upstream rootfs SHA-256 verified before extraction.
- Customized rootfs passed structural boot/session/key/default/extension/browser checks, a second full upgrade, and real `useradd -m` inheritance comparisons before sealing.

## Greeter repair discovered during installation

The initial real GUI installation exposed repeated empty PAM logins on machines without configured fingerprint authentication. Those attempts could lock the account before password entry. The pinned interface fix checks PAM and reader availability, starts unattended authentication only when enrollment can be established, offers an explicit fingerprint button when fprintd's default policy denies the enrollment query, and bounds automatic retries.

The first installed VM was upgraded from the public signed repository. The repaired greeter remained idle with an empty failure record, accepted the password, and started Pond/Vicinae. `pacman -Qkk pond-lockscreen` reported 80 files and zero altered files.

## Fresh final ISO acceptance

Passed on 2026-11-07/08 UTC:

1. Booted the final ISO through UEFI/GRUB with a test-only serial debug shell. The real installer backend downloaded both public release parts and verified the complete archive before extraction.
2. Installed to a blank 40 GiB disk: partitioning/Btrfs subvolumes, user creation, regional/network configuration, full pacman upgrade, hardware detection, initramfs generation and EFI boot setup completed (`INSTALL_SUCCEEDED`).
3. Booted from the installed disk with kernel `7.3.1-4-pond`. SDDM and UFW were active. Left the greeter idle for over two minutes: SDDM recorded no login request and the failure tally was empty.
4. Entered the dummy user's password graphically. Niri/Pond started with North and the exact Ales Krivec image. Dismissed the fork's normal User Manual welcome overlay; no preference files were edited.
5. Mod+Space opened the forked launcher. Its command list already contained `@bflycomputer/pond-pm-extension:install`. Opening it with the query `helium` displayed Helium as installed; the packaged Rust bridge ran and Vicinae logged the extension load.
6. Helium reported `0.21.1.1` (Chromium `157.0.8103.38`) and opened https://example.com using the VM-specific software-rendering invocation described below.
7. `check-installed.sh` passed: nine fork versions matched the recorded source commits, repository resolution selected `pond-custom`, session services/processes and launcher IPC worked, and the new user's three JSON defaults matched the request.
8. Ran another `pacman -Syu --noconfirm` against the public repositories (no further updates were available), rebooted, logged in again, and reran the same checks successfully. The repository order, forks, launcher, extension and requested defaults persisted.

The earlier 1.0.0 test also completed the graphical installer wizard. For the final ISO, the unshipped guest harness exercised that same installation library and the installed system was checked graphically. The inspection helper initially missed the separate `@home` subvolume and attempted an offline firewall reload; those test-only helper issues were corrected after the installation had succeeded. Test transport changes were limited to SSH access and its host-only firewall exception.

## Scope and VM details

KVM/QEMU, Q35, UEFI/OVMF, four vCPUs, 6 GiB RAM, a blank 40 GiB VirtIO disk and a 3D VirtIO GPU. Niri requires a working EGL renderer; the tested 2D VirtIO configuration produced no desktop output. Helium's page test used `--disable-gpu` after accelerated Chromium rendering crashed this host's virtual GPU. This flag is limited to the test invocation and is not shipped in the image.

Test SSH keys, a test-only UFW exception for QEMU's host address, and the dummy VM account were added only to disposable installed disks. The distributed rootfs contains no test account, SSH host key or private repository signing key. The live debug-shell kernel argument is test-only.

Physical GPU/fingerprint hardware, BIOS installation and offline installation have not been verified. GitHub Actions is configured and enabled; these release artifacts were built locally using the same scripts. Rolling upstream dependencies mean rebuilds are repeatable, not byte-for-byte identical.
