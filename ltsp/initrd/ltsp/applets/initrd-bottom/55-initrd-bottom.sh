# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Make root writable using a tmpfs overlay and install ltsp-init

initrd_bottom_cmdline() {
    local scripts

    scripts="$1"; shift
    if [ -f /scripts/functions ]; then
        # Running on initramfs-tools
        rb . /scripts/functions
    else
        # Running on dracut
        rootmnt=/sysroot
        # TODO: check which other variables we need, e.g. ROOT, netroot...
    fi
    run_main_functions "$scripts" "$@"
}

initrd_bottom_main() {
    local loop

    warn "Running $0"
    kernel_variables
    img=${nfsroot##*/}
    if [ -n "$LTSP_LOOP" ]; then
        while read -r loop<&3; do
            NO_PROC=1 rb mount_file "$rootmnt/${loop#/}" "$rootmnt"
        done 3<<EOF
$(echo "$LTSP_LOOP" | tr "," "\n")
EOF
    else
        rb mount_dir "$rootmnt" "$rootmnt"
    fi
    is_writeable "$rootmnt" || rb overlay_root
    rb override_init
    mount | grep -w dev || echo ========NODEV========
}


is_writeable() {
    local dst

    dst="$1"
    chroot "$dst" /usr/bin/test -w / && return 0
    rw mount -o remount,rw "$dst"
    chroot "$dst" /usr/bin/test -w / && return 0
    return 1
}

modprobe_overlay() {
    grep -q overlay /proc/filesystems &&
        return 0
    modprobe overlay &&
        grep -q overlay /proc/filesystems &&
        return 0
    if [ -f "$rootmnt/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko" ]; then
        rb mv /lib/modules /lib/modules.real
        rb ln -s "$rootmnt/lib/modules" /lib/modules
        rb modprobe overlay
        rb rm /lib/modules
        rb mv /lib/modules.real /lib/modules
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
    rb mv "$rootmnt/sbin/init" "$rootmnt/sbin/init.real"
    # I think init can't be just a symlink to ltsp.sh like the other applets,
    # because of initramfs init validation / broken symlink at that point.
    echo '#!/bin/sh
exec /run/ltsp/ltsp.sh init "$@"' > "$rootmnt/sbin/init"
    rb chmod +x "$rootmnt/sbin/init"
    # Jessie needs a 3.18+ kernel and this initramfs-tools hack:
    if grep -qs jessie /etc/os-release; then
        echo "init=${init:-/sbin/init}" >> /scripts/init-bottom/ORDER
    fi
    # Move ltsp to /run to make it available after pivot_root.
    # But initramfs-tools mounts /run with noexec; so use a symlink.
    rb mv /ltsp /run/initramfs/ltsp/
    rb ln -s initramfs/ltsp/ltsp /run/ltsp
}

overlay_root() {
    rb modprobe_overlay
    rb mkdir -p /run/initramfs/ltsp
    rb mount -t tmpfs -o mode=0755 tmpfs /run/initramfs/ltsp
    rb mkdir -p /run/initramfs/ltsp/up /run/initramfs/ltsp/work
    rb mount -t overlay -o upperdir=/run/initramfs/ltsp/up,lowerdir=$rootmnt,workdir=/run/initramfs/ltsp/work overlay "$rootmnt"
    # Seen on 20190516 on stretch-mate-sch and bionic-minimal
    if run-init -n "$rootmnt" /sbin/init 2>&1 | grep -q console; then
        warn "$0 working around https://bugs.debian.org/811479"
        rb mount --bind /dev "$rootmnt/dev"
    fi
}
