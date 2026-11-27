#!/usr/bin/env python3
"""Assert that the selected radio bundle and packaged root contain the power table."""
import hashlib
import json
import pathlib
import sys

NAME = 'MT7986_iPAiLNA_EEPROM_AX6000.bin'
SHA256 = '38fed45fdf32c682790e1a200101bd0bab34340cfa3952cb0b558942c523a0f2'
BUNDLE = 'mt7986-fw-20240823'


def verify_blob(path):
    data = path.read_bytes()
    if len(data) != 2097152 or hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit(f'Unexpected high-power EEPROM contents: {path}')
    return {'path': str(path), 'bytes': len(data), 'sha256': SHA256}


def main():
    mode, tree_path = sys.argv[1:]
    tree = pathlib.Path(tree_path)
    config = dict(line.split('=', 1) for line in (tree / '.config').read_text().splitlines()
                  if line.startswith('CONFIG_') and '=' in line)
    expected = {
        'CONFIG_MTK_MT_WIFI_MT7986_20240823': 'y',
        'CONFIG_MTK_MT_WIFI_MT7986_20260601': None,
        'CONFIG_MTK_MT_WIFI_FIRMWARE_PATH_MT7986': '"' + BUNDLE + '"',
        'CONFIG_MTK_FIRST_IF_IPAILNA': 'y',
        'CONFIG_MTK_FIRST_IF_EEPROM_FLASH': 'y',
        'CONFIG_MTK_WIFI_FW_BIN_LOAD': 'y',
        'CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673': 'y',
    }
    for key, value in expected.items():
        if config.get(key) != value:
            raise SystemExit(f'Incorrect radio configuration: {key}={config.get(key)!r}, expected {value!r}')
    driver = tree / 'package/mtk/drivers/mt_wifi'
    patch = driver / 'patches-7673/048-prefer-highpower-bin-eeprom.patch'
    if 'prefer_bin_eeprom_id' not in patch.read_text():
        raise SystemExit('Missing high-power EEPROM loader patch')
    report = {'bundle': BUNDLE, 'source': verify_blob(driver / 'files' / BUNDLE / NAME)}
    if mode == 'rootfs':
        candidates = list((tree / 'build_dir').glob('target-*/root-mediatek/lib/firmware/' + NAME))
        if len(candidates) != 1:
            raise SystemExit(f'Expected one installed EEPROM in target rootfs, got {candidates}')
        report['installed'] = verify_blob(candidates[0])
    elif mode != 'source':
        raise SystemExit('Mode must be source or rootfs')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
