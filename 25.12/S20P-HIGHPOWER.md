# S20P high-power radio configuration

The highpower workflow (`25.12-clx-s20p.yml`) builds from
`mt7986-clx-s20p.config`, which directly selects the `mt7986-fw-20240823`
firmware bundle and the high-power radio options.

## Verified configuration gap

- `hxlls/ci-immo/configs/base.config` selects
  `CONFIG_MTK_MT_WIFI_MT7986_20240823=y` and firmware path
  `mt7986-fw-20240823`.
- The previously published S20P resolved configuration selected `20260601`.
- In source revision `072cd385386b5b7becad12b5c072d7ee2de01bf7`, the
  2,097,152-byte `MT7986_iPAiLNA_EEPROM_AX6000.bin` exists only in the
  `20240823` bundle. Its SHA-256 is
  `38fed45fdf32c682790e1a200101bd0bab34340cfa3952cb0b558942c523a0f2`.
- `package/mtk/drivers/mt_wifi/Makefile` installs the selected firmware
  directory. Patch `048-prefer-highpower-bin-eeprom.patch` checks for a BIN
  larger than the normal 4096-byte table and then invokes the BIN loader.
  Selecting `20260601` therefore omitted this high-power BIN from packaging.
- The source's N60 Pro defconfig is internally inconsistent: it selects the
  `20240823` choice but writes a `20260601` derived path. Use the resolved
  config and actual packaged files, not that string as a reference.

The configuration matches the reference CI's bundle and keeps MT7986 iPA/iLNA,
flash EEPROM, firmware BIN loading, and driver 7.6.7.3. It does not write
calibration data into the device's flash partition.
The high-power driver loads the bundled table instead of the onboard table;
S20P radio behavior, calibration compatibility and actual transmit power must
be verified on hardware. The original profile is named for N60 Pro, while the
reference CI also selects S20P/S20L; successful compilation alone does not
establish their RF equivalence.

Before publishing, `check-s20p-power-table.py` verifies the resolved choices,
the loader patch, the source BIN and the installed target-rootfs BIN. The
workflow publishes `power-table-verification.json` alongside the firmware.
