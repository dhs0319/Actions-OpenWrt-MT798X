#!/usr/bin/env python3
"""Validate S20P radio and the proxy selected in the shared main configuration."""
import pathlib
import sys


def selections(path):
    result = {}
    for raw in pathlib.Path(path).read_text().splitlines():
        line = raw.split(' #', 1)[0].strip()
        if line.startswith('CONFIG_') and '=' in line:
            key, value = line.split('=', 1)
            result[key.removeprefix('CONFIG_')] = value
    return result


def required_symbols(seed):
    required = {
        'TARGET_mediatek', 'TARGET_mediatek_filogic',
        'TARGET_DEVICE_mediatek_filogic_DEVICE_clx_s20p',
        'PACKAGE_kmod-mediatek_hnat', 'PACKAGE_kmod-mt_wifi',
        'PACKAGE_kmod-warp', 'PACKAGE_kmod-conninfra',
        'MTK_CHIP_MT7986', 'MTK_MT_WIFI_DRIVER_VERSION_7673',
        'MTK_FIRST_IF_IPAILNA', 'MTK_FIRST_IF_EEPROM_FLASH',
        'PACKAGE_luci-app-mtwifi-cfg', 'PACKAGE_firewall4',
    }
    for app, packages in {
        'nikki': ('nikki',),
        'homeproxy': ('sing-box',),
        'rtp2httpd': ('rtp2httpd',),
        'ddns-go': ('ddns-go',),
        'upnp': ('miniupnpd-nftables',),
        'oaf': ('appfilter', 'kmod-oaf'),
    }.items():
        if seed.get('PACKAGE_luci-app-' + app) == 'y':
            required.add('PACKAGE_luci-app-' + app)
            required.update('PACKAGE_' + pkg for pkg in packages)
    return required


def main():
    mode, target, seed_path = sys.argv[1:]
    required = required_symbols(selections(seed_path))
    if mode == 'config':
        config = selections(target)
        missing = sorted(key for key in required if config.get(key) != 'y')
        if missing:
            raise SystemExit('Missing enabled configuration: ' + ', '.join(missing))
        print(f'S20P highpower: {len(required)} required selections retained')
    elif mode == 'image':
        root = pathlib.Path(target)
        images = list(root.glob('*clx_s20p*sysupgrade*.bin'))
        if len(images) != 1 or images[0].stat().st_size == 0:
            raise SystemExit('Expected exactly one nonempty S20P sysupgrade image')
        manifests = list(root.glob('*clx_s20p*.manifest'))
        if not manifests:
            manifests = list(root.glob('*.manifest'))
        if len(manifests) != 1:
            raise SystemExit('Expected one S20P or single-device target manifest')
        packages = {line.split(' - ', 1)[0] for line in manifests[0].read_text().splitlines()}
        wanted = {key.removeprefix('PACKAGE_') for key in required if key.startswith('PACKAGE_')}
        missing = sorted(wanted - packages)
        if missing:
            raise SystemExit('Manifest missing packages: ' + ', '.join(missing))
        print(f'Image {images[0].name}: {images[0].stat().st_size} bytes; {len(wanted)} required packages verified')
    else:
        raise SystemExit('Mode must be config or image')


if __name__ == '__main__':
    main()
