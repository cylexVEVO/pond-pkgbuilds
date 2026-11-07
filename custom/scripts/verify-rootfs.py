#!/usr/bin/env python3
"""Offline assertions, also usable against a mounted VM installation."""
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
for relative in (
    'boot/vmlinuz-linux-pond', 'boot/vmlinuz-linux-pond-lts',
    'usr/share/vicinae/extensions/pond-pm-extension',
    'usr/share/pond-interface/wallpaper/included/ales krivec.jpg',
    'etc/skel/.config/niri/config.kdl', 'usr/share/pacman/keyrings/pond-custom.gpg',
):
    path = root / relative
    # Absolute target symlinks resolve inside the image, not on the builder.
    if path.is_symlink():
        target = path.readlink()
        path = root / str(target).lstrip('/') if target.is_absolute() else path.parent / target
    assert path.exists(), relative
config = root / 'etc/skel/.config'
assert json.loads((config / 'pond-interface/theme.json').read_text())['theme'] == 'north'
wallpaper = json.loads((config / 'pond-interface/wallpaper.json').read_text())
assert wallpaper['mode'] == 'custom'
assert (root / wallpaper['path'].lstrip('/')).is_file()
settings = json.loads((config / 'vicinae/settings.json').read_text())
assert settings['theme']['dark']['name'] == 'pond-north'
assert (root / 'usr/bin/helium-browser').is_symlink()
assert 'DatabaseRequired' in (root / 'etc/pacman.conf').read_text()
assert (root / 'etc/systemd/system/display-manager.service').readlink().name == 'sddm.service'
assert (root / 'etc/systemd/user/graphical-session.target.wants/vicinae.service').is_symlink()
inventory = dict(line.split(maxsplit=1) for line in (root / 'usr/share/pond-custom/packages.txt').read_text().splitlines())
for name in ('pond-shell', 'pond-lockscreen', 'pond-wallpaper', 'pond-screenshot',
             'pond-grub-config', 'pond-plymouth-theme', 'pond-launcher', 'pond-pm', 'pond-pm-extension'):
    assert inventory[name].startswith('1:'), f'{name} was replaced during upgrade'
print('Rootfs defaults, extension, browser, signing key, session and boot files verified')
