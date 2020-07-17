#!/bin/sh
# MIT License
# 
# Copyright (c) 2020 Davide Berardi
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Architecture to build
ARCH="$(uname -m)"
# Version of OpenBSD to download
VER="$(uname -r)"
# Selected HTTP client
HTTP_CLIENT=wget
# Unintended installation script
AUTOINSTALL="/tmp/auto_install.conf"
# Mountpoints to push files in
IMAGE_MOUNTPOINT="/mnt/img"
BSD_MOUNTPOINT="/mnt/bsd"
# Mirror to download from
MIRROR="https://cdn.openbsd.org/pub/OpenBSD/$VER"
# Unprivileged user 
UNPRIVUSER="vagrant"
# Default password
PASSWORD="vagrant"
# Version to setup (without dot for some commands)
SVER="$(echo $VER | tr -d '.')"
# If true, compress the image
do_ZIP=true

set -eu

check_or_install() {
	[ -e "/usr/local/bin/$1" ] || doas pkg_add "$1"
}

check_or_download() {
	FILES=""
	"$HTTP_CLIENT" -c "$(dirname $1)/SHA256"{,.sig}

	for download in $@; do
		[ -e "$(basename $download)" ] || "$HTTP_CLIENT" -c "$download"
		FILES="$(basename $download) $FILES"
	done

	signify -C -p "/etc/signify/openbsd-$SVER-base.pub" -x SHA256.sig $FILES
}

check_or_unarchive() {
	DESTDIR="$1"
	shift

	for archive in $@; do
		# Check if the file is already unarchived in the destination
		test -e "$DESTDIR/$(tar -tzf "$archive" | head -1)" \
			&& echo "Already unarchived" && continue
		tar -C "$DESTDIR" -xzvf "$archive"
	done
}

mount_installfs() {
	doas vnconfig -l
	if ! doas vnconfig -l | grep -q "$1"; then
		echo "Creating a virtual device for '$1' ($(pwd))"
		doas vnconfig "$1"
	fi
	VND="$( doas vnconfig -l | grep "$1" | awk '{print $1}' | sed 's/://' )"

	if ! mount | grep -q "/dev/${VND}a" ;then
		doas mount "/dev/${VND}a" "$2"
	fi
}

umount_installfs() {
	VND="$( doas vnconfig -l | grep "$1" | awk '{print $1}' | sed 's/://' )"
	MP="$( mount | grep /dev/${VND}a | awk '{print $3}' )"

	doas umount "$MP"
	doas vnconfig -u "$VND"
}

create_autoinstall() {
	# This script will configure insecure passwords
	cat >"$1" <<-_END_
	System hostname = openbsd
	Public ssh key for root account = $(cat authorized_keys)
	Password for root = $PASSWORD
	Allow root ssh login = yes
	Setup a user = $UNPRIVUSER
	Password for user = $PASSWORD
	Public ssh key for user vagrant = $(cat authorized_keys)
	What timezone are you in = UTC
	Location of sets = http
	HTTP Server = cdn.openbsd.org
	Set name(s) = -game*.tgz -x*.tgz
	Cannot determine prefetch area. Continue without verification? = yes
	Use (W)hole disk MBR, whole disk (G)PT, (O)penBSD area or (E)dit? = W
	_END_
}

doas mkdir -p "$IMAGE_MOUNTPOINT" "$BSD_MOUNTPOINT"

# If we don't have an http client install it
check_or_install "${HTTP_CLIENT}"

# Download install filesystem
check_or_download "${MIRROR}/${ARCH}/install$SVER.fs"

cp "install$SVER.fs" "install$SVER.mod.fs"
create_autoinstall "$AUTOINSTALL"

mount_installfs "$(pwd)/install$SVER.mod.fs" "$IMAGE_MOUNTPOINT"

# Update the autoinstall file
echo "Updating bsd.rd"
doas cp "/bsd.rd" "/tmp/bsd.rd"
# Change the root path
doas rdsetroot -x "/bsd.rd" >"/tmp/bsd.fs"
mount_installfs "/tmp/bsd.fs" "$BSD_MOUNTPOINT"

doas cp "$AUTOINSTALL" "$BSD_MOUNTPOINT/auto_install.conf"

umount_installfs "/tmp/bsd.fs" "$BSD_MOUNTPOINT"
doas rdsetroot "/tmp/bsd.rd" "/tmp/bsd.fs"

# Free some space in the target image
echo "Freeing space"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/base$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/comp$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/game$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/man$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/xbase$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/xfont$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/xserv$SVER.tgz"
doas rm -rf "$IMAGE_MOUNTPOINT/$VER/$ARCH/xshare$SVER.tgz"

# Overwrite the standard boot file and ramdisks
doas cp -f "/tmp/bsd.rd" "$IMAGE_MOUNTPOINT/bsd.rd"
doas cp -f "/tmp/bsd.rd" "$IMAGE_MOUNTPOINT/$VER/$ARCH/bsd.rd"

doas chmod +x "$IMAGE_MOUNTPOINT/boot"
doas chmod +x "$IMAGE_MOUNTPOINT/bsd.rd"
doas chmod +x "$IMAGE_MOUNTPOINT/$VER/$ARCH/bsd.rd"

umount_installfs "$(pwd)/install$SVER.mod.fs" "$IMAGE_MOUNTPOINT"

echo "Done"
