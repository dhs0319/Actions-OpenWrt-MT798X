#!/bin/bash
# 参考 VIKINGYFY/OpenWRT-CI 的 Packages.sh，插件列表保持与原 istore/diy-part1.sh、diy-part2.sh 一致

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}
	local REPO_PATH="./package/$REPO_NAME"

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库（分支留空则使用仓库默认分支）
	rm -rf "$REPO_PATH"
	if [ -n "$PKG_BRANCH" ]; then
		git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git" "$REPO_PATH"
	else
		git clone --depth=1 --single-branch "https://github.com/$PKG_REPO.git" "$REPO_PATH"
	fi

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find $REPO_PATH/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./package \;
		rm -rf $REPO_PATH
	fi
}

# UPDATE_PACKAGE "包名" "项目地址" "项目分支，留空为默认分支" "pkg，可选，从大杂烩中单独提取包名插件" "需要一并从 feeds 删除的同类包名"

#主题
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"

#科学插件
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "" "pkg"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "master" "pkg"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" ""
#HomeProxy 及配套 sing-box
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "" "" "axonhub gecoosac sing-box luci-app-homeproxy luci-app-timewol luci-app-wolplus luci-app-wolultra"
#Daed 及 vmlinux-btf
# UPDATE_PACKAGE "daed" "kenzok8/openwrt-daede" ""
# UPDATE_PACKAGE "vmlinux-btf" "QiuSimons/vmlinux-btf" ""

#功能插件
UPDATE_PACKAGE "luci-app-poweroffdevice" "sirpdboy/luci-app-poweroffdevice" ""
UPDATE_PACKAGE "luci-app-owq-wol" "isalikai/luci-app-owq-wol" ""
UPDATE_PACKAGE "lucky" "gdy666/luci-app-lucky" ""
UPDATE_PACKAGE "rtp2httpd" "stackia/rtp2httpd" ""
UPDATE_PACKAGE "luci-app-watchdog" "sirpdboy/luci-app-watchdog" ""
UPDATE_PACKAGE "luci-app-taskplan" "sirpdboy/luci-app-taskplan" ""
UPDATE_PACKAGE "luci-app-authshield" "iv7777/luci-app-authshield" ""
UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "" "" "luci-app-oaf open-app-filter"
UPDATE_PACKAGE "luci-app-accesscontrol" "janvanstiphout/luci-app-accesscontrol" ""
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "v2ray-geodata" "sbwml/v2ray-geodata" ""

#VPN
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" ""
UPDATE_PACKAGE "luci-app-tailscale-community" "Tokisaki-Galaxy/luci-app-tailscale-community" ""

#替换整个源码目录
REPLACE_FEED() {
	local FEED_DIR=$1
	local FEED_REPO=$2
	local FEED_BRANCH=$3

	echo " "
	rm -rf "$FEED_DIR"
	if [ -n "$FEED_BRANCH" ]; then
		git clone --depth=1 --single-branch --branch "$FEED_BRANCH" "https://github.com/$FEED_REPO.git" "$FEED_DIR"
	else
		git clone --depth=1 --single-branch "https://github.com/$FEED_REPO.git" "$FEED_DIR"
	fi
	rm -rf "$FEED_DIR/.git"
	echo "$FEED_DIR has been replaced by $FEED_REPO!"
}

#golang 升级（mosdns 等需要较新的 golang）
REPLACE_FEED "./feeds/packages/lang/golang" "sbwml/packages_lang_golang" "26.x"
#smartdns 升级
REPLACE_FEED "./feeds/packages/net/smartdns" "pymumu/openwrt-smartdns" "master"
REPLACE_FEED "./feeds/luci/applications/luci-app-smartdns" "pymumu/luci-app-smartdns" "master"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./package/ ./feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
