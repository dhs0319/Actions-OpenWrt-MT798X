#!/bin/bash
# 参考 VIKINGYFY/OpenWRT-CI 的 Settings.sh，并合入原 istore/diy-part2.sh 的系统设置

#移除luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" {} +

WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	[ -n "$WRT_SSID" ] && sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	[ -n "$WRT_WORD" ] && sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
[ -n "$WRT_NAME" ] && sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#网络参数优化（sysctl）
mkdir -p ./files/etc/sysctl.d/
cat > ./files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'
# ---------------------------------------------------------
# Conntrack（daed/代理高并发必需）
# ---------------------------------------------------------
# 默认 16384，代理场景适当放大
net.netfilter.nf_conntrack_max=32768
# 默认 432000(5天)，缩短回收空闲连接
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=120

# ---------------------------------------------------------
# TCP 优化
# ---------------------------------------------------------
net.core.netdev_max_backlog=2048
net.core.somaxconn=2048
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_tw_buckets=8192

# ---------------------------------------------------------
# 缓冲区（适配 256MB 路由器）
# ---------------------------------------------------------
# 单 socket 最大收/发缓冲 4MB（默认 208KB）
net.core.rmem_max=4194304
net.core.wmem_max=4194304
# TCP 自动调优：min=4KB, default=128KB, max=4MB
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
# UDP 内存限制（单位：页=4KB）：min=32MB pressure=48MB max=64MB
net.ipv4.udp_mem=8192 12288 16384

# ---------------------------------------------------------
# 本地端口范围
# ---------------------------------------------------------
net.ipv4.ip_local_port_range=1024 65535
SYSCTL

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

echo "Settings.sh finished!"
