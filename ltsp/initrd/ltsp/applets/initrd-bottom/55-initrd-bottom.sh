# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Make root writable using a tmpfs overlay and install ltsp-init

initrd_bottom_cmdline() {
    local scripts

    scripts="$1"; shift
    if [ -f /scripts/functions ]; then
        # Running on initramfs-tools
        re . /scripts/functions
    else
        # Running on dracut
        rootmnt=/sysroot
        # TODO: check which other variables we need, e.g. ROOT, netroot...
    fi
    run_main_functions "$scripts" "$@"
    debug_shell
}

initrd_bottom_main() {
    local loop img_src

    warn "Running $0"
    kernel_variables
    if [ -n "$LTSP_IMAGE" ]; then
        img_src=$LTSP_IMAGE
        # If it doesn't start with slash, it's relative to $rootmnt
        if [ "${img_src#/}" = "$img_src" ]; then
            img_src="$rootmnt/$img_src"
        fi
        re mount_img_src "$img_src" "$rootmnt"
    elif [ ! -d "$rootmnt/proc" ]; then
        die "$rootmnt/proc doesn't exist and ltsp.image wasn't specified"
    fi
    test -d "$rootmnt/proc" || die "$rootmnt/proc doesn't exist in initrd-bottom"
    test "$LTSP_OVERLAY" = "0" || re overlay_root
    re override_init
}

modprobe_overlay() {
    local overlayko

    grep -q overlay /proc/filesystems &&
        return 0
    modprobe overlay &&
        grep -q overlay /proc/filesystems &&
        return 0
    overlayko="$rootmnt/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko"
    if [ -f "$overlayko" ]; then
        # Do not `ln -s "$rootmnt/lib/modules" /lib/modules`
        # In that case, /root is in use after modprobe
        warn "Loading overlay module from real root" >&2
        # insmod is availabe in Debian initramfs but not in Ubuntu
        "$rootmnt/sbin/insmod" "$overlayko" &&
            grep -q overlay /proc/filesystems &&
            return 0
    fi
    return 1
}

override_init() {
    # To avoid specifying an init=, we override the real init.
    # We can't mount --bind as it's in use by libraries and can't be unmounted.
    # In some cases we could create a symlink to /run/ltsp/ltsp.sh,
    # but it doesn't work in all initramfs-tools versions.
    # So let's be safe and use plain cp.
    re mv "$rootmnt/sbin/init" "$rootmnt/sbin/init.real"
    # I think init can't be just a symlink to ltsp.sh like the other applets,
    # because of initramfs init validation / broken symlink at that point.
    echo '#!/bin/sh
exec /run/ltsp/ltsp.sh init "$@"' > "$rootmnt/sbin/init"
    re chmod +x "$rootmnt/sbin/init"
    # Jessie needs a 3.18+ kernel and this initramfs-tools hack:
    if grep -qs jessie /etc/os-release; then
        echo "init=${init:-/sbin/init}" >> /scripts/init-bottom/ORDER
    fi
    # Move ltsp to /run to make it available after pivot_root.
    # But initramfs-tools mounts /run with noexec; so use a symlink.
    re mv /ltsp /run/initramfs/ltsp/
    re ln -s initramfs/ltsp/ltsp /run/ltsp
}

overlay_root() {
    re modprobe_overlay
    re mkdir -p /run/initramfs/ltsp
    re mount -t tmpfs -o mode=0755 tmpfs /run/initramfs/ltsp
    re mkdir -p /run/initramfs/ltsp/up /run/initramfs/ltsp/work
    re mount -t overlay -o upperdir=/run/initramfs/ltsp/up,lowerdir=$rootmnt,workdir=/run/initramfs/ltsp/work overlay "$rootmnt"
}
