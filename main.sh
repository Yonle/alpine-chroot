#!/usr/bin/env bash

[ $(uname -s) != "Linux" ] && exec echo "Expected Linux kernel, But got unsupported kernel ($(uname -s))."
[ $(id -u) != 0 ] &&  {
	[ -x alpine-proot.sh ] && exec bash alpine-proot.sh
	echo "It seems like you didn't run this as root, or you didn't have root."
	echo "However, You may try alpine-proot for non-root device / permission."
	read -p "Install alpine-proot now [y/n]? " s
	case $s in
		y|Y)  {
			curl -L#o alpine-proot.sh https://raw.githubusercontent.com/Yonle/alpine-proot/master/main.sh
			[ $? != 0 ] && exit 1
			chmod +x alpine-proot.sh
			echo "Next time, Run this command to launch alpine-proot:"
			echo "  ./alpine-proot.sh"
			exec bash alpine-proot.sh
		} ;;
		*)  exit 6 ;;
	esac
}

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
	mount -o bind /$i $CONTAINER_PATH/$i
	[ $? != 0 ] && exec echo -e "\nIt seems like you're running alpine-chroot with faked uid. However this is not gonna work anyway because alpine-chroot requires REAL ROOT to mount & unmount some common path to guest such as /dev, /proc, and /sys. Rerun this script without fake root/fake uid utilities for more informattion."
done

cmd=$@
chroot $CONTAINER_PATH ${cmd:-/bin/su -l}

for i in dev proc sys; do
	umount $CONTAINER_PATH/$i
	[ $? != 0 ] && exec echo -e "\nIt seems like you're running alpine-chroot with faked uid. However this is not gonna work anyway because alpine-chroot requires REAL ROOT to mount & unmount some common path to guest such as /dev, /proc, and /sys. Rerun this script without fake root/fake uid utilities for more information."
done
