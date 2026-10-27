#!/bin/bash
# 自定义 feeds：必须在 ./scripts/feeds update 之前执行

FEEDS_CONF="./feeds.conf.default"

ADD_FEED() {
	local FEED_NAME=$1
	local FEED_LINE=$2

	if grep -qE "^src-[a-z]+ $FEED_NAME " "$FEEDS_CONF"; then
		echo "feed $FEED_NAME already exists, skip!"
	else
		echo "$FEED_LINE" >> "$FEEDS_CONF"
		echo "feed $FEED_NAME has been added!"
	fi
}

#NAS
ADD_FEED "nas" "src-git nas https://github.com/linkease/nas-packages.git;master"
ADD_FEED "nas_luci" "src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main"
#iStore
ADD_FEED "istore" "src-git istore https://github.com/linkease/istore;main"

cat "$FEEDS_CONF"
