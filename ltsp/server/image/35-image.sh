# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Generate a squashfs image from an image source
# Vendors can add to $_DST_DIR between image_main and finalize_main

image_cmdline() {
    local scripts args _DST_DIR img_name

    scripts="$1"; shift
    args=$(re getopt -n "$_LTSP_APPLET" -o "hk:V" \
        -l "help,kernel:,version" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -b|--backup) shift; BACKUP="$1" ;;
            -c|--cleanup) shift; CLEANUP="$1" ;;
            -h|--help) applet_usage; exit 0 ;;
            -k|--kernel-initrd) shift; KERNEL_INITRD="$1" ;;
            -m|--mksquashfs-params) shift; MKSQUASHFS_PARAMS="$1" ;;
            -r|--revert) shift; REVERT=1 ;;
            -V|--version) applet_version; exit 0 ;;
            --) shift; break ;;
            *) die "$_LTSP_APPLET: error in cmdline" ;;
        esac
        shift
    done
    if [ "$#" -eq 0 ]; then
        img_name=$(list_img_names)
        set -- $img_name
        if [ "$#" -gt 3 ] && [ "$ALL_IMAGES" != "1" ]; then
            die "Refusing to run $_LTSP_APPLET for $# detected images!
Please export ALL_IMAGES=1 if you want to allow this"
        fi
    fi
    for img_name in "$@"; do
        _DST_DIR=""
        run_main_functions "$scripts" "$img_name"
    done
}

image_main() {
    local img_src img img_name

    img_src="$1"
    img_path=$(add_path_to_src "${img_src%%,*}")
    img_name=$(img_path_to_name "$img_path")
    re test "image_main:$img_name" != "image_main:"
    _DST_DIR=$(re mktemp -d)
    exit_command "rw rmdir '$_DST_DIR'"
    # _DST_DIR has mode=0700; use a subdir to hide the mount from users
    _DST_DIR="$_DST_DIR/ltsp"
    re mkdir -p "$_DST_DIR"
    exit_command "rw rmdir '$_DST_DIR'"
    re mount_img_src "$img_src" "$_DST_DIR"
    overlay "$_DST_DIR" "$_DST_DIR"
}
