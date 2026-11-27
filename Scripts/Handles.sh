#!/bin/bash
# 参考 VIKINGYFY/OpenWRT-CI 的 Handles.sh，修补内容迁移自原 istore/diy-part2.sh、diy-partX.sh、25.12/diy-part2.sh

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -n "$GUARD" ] && [ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#菜单迁移：MOVE_MENU <插件目录> <原路径> <新路径> <原父级> <新父级>
MOVE_MENU() {
	local DIR=$1
	find "$DIR" -type f -exec sed -i "s|admin/services/$2|admin/$3/$2|g" {} + && \
	find "$DIR" -type f -exec sed -i "s/\"parent\": \"luci.$4\"/\"parent\": \"luci.$5\"/g" {} +
}

#QuickStart 首页温度显示修复（替换 istore_backend.lua）
CUSTOM_LUA="$GITHUB_WORKSPACE/istore/istore_backend.lua"
TARGET_LUA=$(find $FEEDS_PATH $PACKAGE_PATH -name "istore_backend.lua" -type f 2>/dev/null | head -n 1)
if [ -n "$TARGET_LUA" ] && [ -f "$CUSTOM_LUA" ]; then
	FIX "quickstart" "$(dirname "$TARGET_LUA")" cp -f "$CUSTOM_LUA" "$TARGET_LUA"
fi

#libxcrypt 编译参数修复：禁用 werror，注入 -fcommon
XCRYPT_MK="$FEEDS_PATH/packages/libs/libxcrypt/Makefile"
FIX "libxcrypt" "$(dirname "$XCRYPT_MK")" sed -i \
	"s/CONFIGURE_ARGS[ \t]*+=[ \t]*/&--disable-werror /; s/TARGET_CFLAGS[ \t]*+=[ \t]*/&-fcommon /" \
	"$XCRYPT_MK"

#修改tailscale菜单位置：服务 -> VPN
TS_DIR=$(find $FEEDS_PATH $PACKAGE_PATH -type d -name "luci-app-tailscale-community" 2>/dev/null | head -n 1)
FIX "tailscale-community" "$TS_DIR" find "$TS_DIR" -type f -name "*.json" -exec sed -i \
	's|admin/services/tailscale|admin/vpn/tailscale|g; s/"parent": "luci.services"/"parent": "luci.vpn"/g' {} +

#修改ksmbd菜单位置：服务 -> NAS
KSMBD_DIR=$(find $FEEDS_PATH/luci -type d -name "luci-app-ksmbd" 2>/dev/null | head -n 1)
FIX "ksmbd" "$KSMBD_DIR" MOVE_MENU "$KSMBD_DIR" "ksmbd" "nas" "services" "nas"

#修改openlist2菜单位置：服务 -> NAS
OPENLIST2_DIR=$(find $FEEDS_PATH $PACKAGE_PATH -type d -name "luci-app-openlist2" 2>/dev/null | head -n 1)
FIX "openlist2" "$OPENLIST2_DIR" MOVE_MENU "$OPENLIST2_DIR" "openlist2" "nas" "services" "nas"

#Ruby 默认关闭 YJIT，避免引入 rust/host
RUBY_MK=$(find $FEEDS_PATH -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)
FIX "ruby-yjit" "$(dirname "${RUBY_MK:-/nonexistent/x}")" sed -i \
	'/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"

#内核配置追加（OpenWrt 25.x / kernel 6.12+）：eBPF、XDP、conntrack 增强
KCONF_DIR="./target/linux/mediatek/filogic"
APPEND_KCONF() {
	local CONF
	for CONF in "$KCONF_DIR"/config-*; do
		[ -f "$CONF" ] || continue
		cat >> "$CONF" << 'EOF'

# Cgroup BPF（daed 必需，SOCK_CGROUP_DATA 已被自动选中）
CONFIG_CGROUP_BPF=y

# eBPF 增强（BPF/BPF_SYSCALL/BPF_JIT 已是 25.x 默认值）
CONFIG_BPF_JIT_ALWAYS_ON=y

# eBPF 网络调度（NET_SCHED 已是默认值）
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_BPF=m
CONFIG_NET_CLS_BPF=m

# XDP / 高速数据路径
CONFIG_XDP_SOCKETS=y
CONFIG_BPF_STREAM_PARSER=y

# 诊断接口（INET_DIAG 已是默认值）
CONFIG_INET_TCP_DIAG=y

# Conntrack 增强（EVENTS/CT_NETLINK 已是默认值）
CONFIG_NF_CONNTRACK_TIMESTAMP=y
CONFIG_NF_CONNTRACK_LABELS=y
EOF
	done
}
FIX "kernel-config" "$KCONF_DIR" APPEND_KCONF
