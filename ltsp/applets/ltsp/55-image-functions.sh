# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Functions for chroot/VM/squashfs manipulation, used by:
# chroot, image, info?, ipxe?, kernel, nbd-server?, initrd-bottom
# So we can't have /etc/ltsp/applet.conf with [sections];
# let's put everything in a global /etc/ltsp/ltsp.conf instead

# List the full path to the specified (or all) images, one per line
list_images() {
    local paramc img_src img img_name

    paramc="$#"
    if [ "$paramc" = "0" ]; then
        set -- "$BASE_DIR/"*
    fi
    for img_src in "$@"; do
        # Extract its path, without the options/submounts
        img=${img_src%%,*}
        img_src=${img_src#$img}
        # If it doesn't start with . or /, it's relative to $BASE_DIR
        if [ "${img}" = "${img#.}" ] && [ "${img}" = "${img#/}" ]; then
            img=$(re readlink -f "$BASE_DIR/$img")
        else
            img=$(re readlink -f "$img")
        fi
        # Put back the canonicalized path
        img_src="$img$img_src"
        if [ ! -e "$img" ]; then
            die "Image doesn't exist: $img"
        fi
        # Get its its basename
        img_name=${img##*/}
        # Prefer to list chroots first; override by specifying the full path
        if [ -d "$img/proc" ]; then
            echo "$img_src"
        elif [ "$_APPLET" != "image" ] && [ -e "$img/ltsp.img" ]; then
            # `ltsp image` shouldn't list the squashfs images
            img_src=${img_src#$img}
            img_src="$img/ltsp.img$img_src"
            echo "$img_src"
        elif [ -e "$img/$img_name-flat.vmdk" ]; then
            img_src=${img_src#$img}
            img_src="$img/$img_name-flat.vmdk$img_src"
            echo "$img_src"
        elif [ "$paramc" = 0 ]; then
            # End of autodetection
            continue
        else
            echo "$img_src"
        fi
    done
}

# Process a series of mount sources to mount an image to dst, for example:
#   img_src1,mount-options1,,img_src2,mount-options2,,img3 dst
# Image sources must come from "list_images" and contain full path info.
# The following rules apply:
#   * If it's a directory, it's bind-mounted over $dst[/$subdir].
#   * If it's a file, the (special) mount options along with autodetection
#     are used to loop mount it over $dst[/$subdir].
# The following special mount options are recognized at the start of options:
#   * partition=1|etc
#   * fstype=squashfs|iso9660|ext4|vfat|etc
#   * subdir=boot/efi (mount $img in $dst/$subdir)
# The rest are passed as mount -o options (comma separated).
# After all the commands have been processed, if /proc doesn't exist,
# it's considered an error.
# Examples for boot.ipxe:
# set nfs_simple root=/dev/nfs nfsroot=${srv}:/srv/ltsp/${img} (no image required)
# set nfs_squashfs root=/dev/nfs nfsroot=${srv}:/srv/ltsp/${img} ltsp.image=ltsp.img
# set nfs_vbox root=/dev/nfs nfsroot=${srv}:/srv/ltsp/${img} ltsp.image=${img}-flat.vmdk
# set nfs_ubuntu_iso root=/dev/nfs nfsroot=${srv}:/srv/ltsp/cd ltsp.image=ubuntu-mate-18.04.1-desktop-i386.iso,fstype=iso9660,loop,ro,,casper/filesystem.squashfs,fstype=squashfs,loop,ro
# root=/dev/sda1 ltsp.image=/path/to/VMs/bionic-mate-flat.vmdk,partition=1
# Examples for ltsp image:
# ltsp image -c /,,/boot/efi,subdir=boot/efi
mount_list() {
    local img_src dst options img partition fstype subdir var_value value

    img_src=$1
    dst=$2
    # img_src MUST come from list_images, i.e. have path information
    re test "img_src$img_src" != "img_src${img_src##*/}"
    re test -d "$dst"
    dst=${dst%/}  # Remove the final slash
    while [ -n "$img_src" ]; do
        img=${img_src%%,,*}
        img_src=${img_src#$img}
        img_src=${img_src#,,}
        img_path=${img%%,*}
        options=${img#$img_path}
        options=${options#,}
        img=$img_path
        partition=
        fstype=
        subdir=
        while [ -n "$options" ]; do
            var_value=${options%%,*}
            value=${var_value#*=}
            case "$options" in
                fstype=*)  fstype=$value ;;
                partition=*)  partition=$value ;;
                subdir=*)  subdir=$value ;;
                *)  break  ;;
            esac
            options=${options#$var_value}
            options=${options#,}
        done
        # list_image returns absolute paths for initial mounts.
        # Submounts may be relative to $dst.
        if [ "${img#/}" = "$img" ]; then
            img=$dst/$img
        fi
        debug "img_src=$img_src
img=$img
options=$options
partition=$partition
fstype=$fstype
subdir=$subdir
"
        # Now we have full path information
        if [ -d "$img" ]; then
            # TODO: it's for debugging, remove the next line
            re test "$img" != "$dst"
            re mount --bind "$img" "$dst/$subdir"
            exit_command "rw umount '$dst/$subdir'"
        elif [ -e "$img" ]; then
            re mount_file "$img" "$dst/$subdir" "$options" "$fstype" "$partition"
        fi
    done
    # After the mount list is done, $dst/proc must exist, otherwise fail
    # TODO: put this in ltsp image etc: test -d "$dst/proc" || die "$dst/proc doesn't exist after mount_list"
}

# Get the mount type of a device; may also return special types for convenience
mount_type() {
    # result=$(mount_type "$src") means we're already in a subshell,
    # no need to worry about namespace pollution
    src=$1
    vars=$(re blkid -po export "$src")
    # blkid outputs invalid characters in e.g. APPLICATION_ID=, grep it out
    eval "$(echo "$vars" | grep -E '^PART_ENTRY_TYPE=|^PTTYPE=|^TYPE=')"
    if [ -n "$PTTYPE" ] && [ -z "$TYPE" ]; then
        # "gpt" or "dos" (both for the main and the extended partition table)
        # .iso CDs also get "dos", but they also get TYPE=, which works
        echo "gpt"
    elif [ "$PART_ENTRY_TYPE" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]; then
        # We ignore the efi partition; it doesn't contain root nor kernels
        echo ""
    elif [ "$TYPE" = "swap" ]; then
        # We ignore swap partitions too
        echo ""
    else
        echo "$TYPE"
    fi
}

# Try to loop mount a raw partition/disk file to dst
mount_file() {
    local src dst options fstype partition loopdev loopparts noload

    src="$1"
    dst="$2"
    options="$3"
    fstype="$4"
    partition="$5"
    re test -e "$src"
    re test -d "$dst"
    # Work around https://bugs.busybox.net/show_bug.cgi?id=11941
    re modprobe loop max_part=9
    fstype=${fstype:-$(mount_type "$src")}
    if [ "$fstype" = "gpt" ]; then  # A partition table
        unset fstype
        loopdev=$(re losetup -f)
        # Note, klibc losetup doesn't support -r (read only)
        warn "Running: " losetup "$loopdev" "$src"
        re losetup "$loopdev" "$src"
        exit_command "rw losetup -d '$loopdev'"
        test -f /scripts/functions || partprobe "$loopdev"
        loopparts="${loopdev}p${partition:-*}"
    elif [ -n "$fstype" ]; then  # A filesystem (partition)
        unset loopparts
    else
        die "I don't know how to mount $src"
    fi
    for image in ${loopparts:-"$src"}; do
        # No need to run blkid again if it was a filesystem
        if [ -n "$loopparts" ]; then
            fstype=${fstype:-$(mount_type "$image")}
        fi
        case "$fstype" in
            "")  continue ;;
            ext*)  options=${options:-ro,noload} ;;
            *)  options=${options:-ro} ;;
        esac
        warn "Running: " mount -t "$fstype" ${options:+-o "$options"} "$image" "$dst"
        re mount -t "$fstype" ${options:+-o "$options"} "$image" "$dst"
        exit_command "rw umount '$dst'"
        return 0
    done
    die "I don't know how to mount $src"
}

modprobe_overlay2() {
    grep -q overlay /proc/filesystems &&
        return 0
    modprobe overlay &&
        grep -q overlay /proc/filesystems &&
        return 0
    if [ -n "$rootmnt" ] &&
        [ -f "$rootmnt/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko" ]
    then
        echo "Loading overlay module from real root" >&2
        re mv /lib/modules /lib/modules.real
        re ln -s "$rootmnt/lib/modules" /lib/modules
        re modprobe overlay
        re rm /lib/modules
        re mv /lib/modules.real /lib/modules
        grep -q overlay /proc/filesystems &&
            return 0
    fi
    return 1
}

overlay_dir2() {
    re modprobe_overlay
    re mkdir -p /run/initramfs/ltsp
    re mount -t tmpfs -o mode=0755 tmpfs /run/initramfs/ltsp
    re mkdir -p /run/initramfs/ltsp/up /run/initramfs/ltsp/work
    re mount -t overlay -o upperdir=/run/initramfs/ltsp/up,lowerdir=$rootmnt,workdir=/run/initramfs/ltsp/work overlay "$rootmnt"
}
