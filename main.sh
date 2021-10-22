#!/usr/bin/env bash

[ $(id -u) != 0 ] && echo -e "alpine-chroot must be run with root.\nIf you don't have root, You may try alpine-proot:\n  sh -c \"\$(curl -sL git.io/alpine-proot)\"" && exit 6
[ ! $HOME ] && export HOME=/home
[ ! $PREFIX ] && [ -x /usr ] && [ -d /usr ] && export PREFIX=/usr
[ ! $TMPDIR ] && export TMPDIR=/tmp
[ ! $CONTAINER_PATH ] && export CONTAINER_PATH="$HOME/.alpinelinux_container"
[ ! $CONTAINER_DOWNLOAD_URL ] && export CONTAINER_DOWNLOAD_URL="https://dl-cdn.alpinelinux.org/alpine/v3.14/releases/$(uname -m)/alpine-minirootfs-3.14.2-$(uname -m).tar.gz"

if [ -z $(command -v gzip) ] || [ ! -x $(command -v gzip) ]; then
	echo "gzip is required in order to extract Alpine rootfs."
	echo "More information can go to https://curl.se/libcurl"
	exit 6
fi

# Install / Reinstall if container directory is unavailable or empty.
if [ ! -d $CONTAINER_PATH ] || [ -z "$(ls -A $CONTAINER_PATH)" ] || [ ! -x $CONTAINER_PATH/bin/busybox ]; then
	# Download rootfs if there's no rootfs download cache.
	if [ ! -f $HOME/.cached_rootfs.tar.gz ]; then
		if [ ! -x $(command -v curl) ]; then
			[ "$(uname -o)" = "Android" ] && pkg=$(command -v pkg) && pkg install curl -y && alpineproot $@ && exit 0
			echo "libcurl is required in order to download rootfs manually"
			echo "More information can go to https://curl.se/libcurl"
			exit 6
		fi
		curl -L#o $HOME/.cached_rootfs.tar.gz $CONTAINER_DOWNLOAD_URL
		if [ $? != 0 ]; then exit 1; fi
	fi

	[ ! -d $CONTAINER_PATH ] && mkdir -p $CONTAINER_PATH

	tar -xzf $HOME/.cached_rootfs.tar.gz -C $CONTAINER_PATH

	# If extraction fail, Delete cached rootfs and exit
	[ $? != 0 ] && rm -f $HOME/.cached_rootfs.tar.gz && exit 1

	echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" > $CONTAINER_PATH/etc/resolv.con
fi

for i in dev proc sys; do
	mount -v /$i $CONTAINER_PATH/$i
done

cmd=$@
chroot $CONTAINER_PATH ${cmd:-/bin/su}

for i in dev proc sys; do
	umount -v $CONTAINER_PATH/$i
done
