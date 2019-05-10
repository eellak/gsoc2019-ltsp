#!/bin/sh
# This file is part of masd, https://masd.github.io
# Copyright 2018 the masd team, see AUTHORS.
# SPDX-License-Identifier: GPL-3.0-or-later
# Create and export masd-overlay.

# Fail on error, to notify nbd-server that the overlay wasn't created.
set -e
OVERLAY=$1
test -n "$OVERLAY"
# Create the directory
mkdir -p "${OVERLAY%/*}"
# Remove the file in case it already exists and it's in use by another process
rm -f "$OVERLAY"
# Create a sparse file. 1 GB per client sounds fine.
dd if=/dev/zero of="$OVERLAY" bs=1 count=0 seek=1G 2>/dev/null
# Use ext2, as ext4 may have additional options not supported by older systems
mkfs.ext2 -L masd-overlay "$OVERLAY"
# TODO: use those fancy mount namespaces, to hide the temp mount
mkdir -p "$OVERLAY-mount"
mount "$OVERLAY" "$OVERLAY-mount"
cp -a /home/Public/Development/masd/var/lib/masd/. "$OVERLAY-mount/"
sync
umount "$OVERLAY-mount"
sync
rmdir "$OVERLAY-mount"


# NBD server doesn't always call the postrun action that removes the overlay:
# https://github.com/NetworkBlockDevice/nbd/issues/47
# To work around that, delete the file after 10 seconds.
# The kernel won't remove it from disk while nbd-server is still using it.
# The stdio redirection helps in daemonizing the task.
# TODO: if nbd-client reconnections ever work properly, we would then like
# to export the same file per client without removing/erasing it first.
( sleep 10; rm -f "$OVERLAY" ) >/dev/null 2>&1 &
