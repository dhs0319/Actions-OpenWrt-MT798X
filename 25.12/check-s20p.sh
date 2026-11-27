#!/bin/bash
# S20P 高功率专项校验，由 WRT-CORE.yml 通过 WRT_VERIFY 调用，工作目录为源码根目录（./wrt/）
# 用法：check-s20p.sh config   编译前：校验最终 .config 与源码中的高功率 EEPROM
#       check-s20p.sh image    编译后：校验固件、软件包清单与目标 rootfs 中的 EEPROM

set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORKSPACE="${GITHUB_WORKSPACE:-$HERE/..}"
REPORT_DIR="$WORKSPACE/build-reports"
mkdir -p "$REPORT_DIR"

# 种子配置 = 实际拼接进 .config 的机型配置与通用配置，用来推导必须保留的选项
SEED=$(mktemp)
trap 'rm -f "$SEED"' EXIT
cat "$WORKSPACE/Config/$WRT_CONFIG.txt" "$WORKSPACE/Config/GENERAL.txt" > "$SEED"

case "${1:-}" in
config)
	python3 "$HERE/check-s20p-power-table.py" source .
	python3 "$HERE/check-s20p-highpower.py" config .config "$SEED"
	;;
image)
	python3 "$HERE/check-s20p-highpower.py" image bin/targets/mediatek/filogic "$SEED"
	# 报告以 verify- 开头，WRT-CORE.yml 会将其随固件一起发布
	python3 "$HERE/check-s20p-power-table.py" rootfs . | tee "$REPORT_DIR/verify-power-table.json"
	;;
*)
	echo "Usage: $0 config|image" >&2
	exit 2
	;;
esac
