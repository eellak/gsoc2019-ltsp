# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create a squashfs image from an image source

image_cmdline() {
    local scripts args

    scripts="$1"; shift
    args=$(re getopt -n "$_LTSP_APPLET" -o "hk:V" \
        -l "help,kernel:,version" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -b|--backup) [=0|1]
            -c|--cleanup) [=0|1]
            -h|--help) applet_usage; exit 0 ;;
            -k|--kernel-initrd) shift; KERNEL_INITRD="$1" ;;
            -m|--mksquashfs-params)
            -r|--revert)
            -V|--version) applet_version; exit 0 ;;
            --) shift; break ;;
            *) die "$_LTSP_APPLET: error in cmdline" ;;
        esac
        shift
    done
    run_main_functions "$scripts" "$@"
}

image_main() {
    local tmp img_src img img_name

    echo "Chroots:"
    list_img_names -c
    if [ "$#" -eq 0 ]; then
        tmp=$(list_img_names)
        set -- $tmp
    fi
    for img_src in "$@"; do
        img_path=$(add_path_to_src "${img_src%%,*}")
        img_name=$(img_path_to_name "$img_path")
        re test "kernel_main:$img_name" != "kernel_main:"
        tmp=$(re mktemp -d)
        exit_command "rw rmdir '$tmp'"
        # tmp has mode=0700; use a subdir to hide the mount from users
        re mkdir -p "$tmp/ltsp"
        exit_command "rw rmdir '$tmp/ltsp'"
        tmp=$tmp/ltsp
        re mount_img_src "$img_src" "$tmp"
        re mkdir -p "$TFTP_DIR/ltsp/$img_name/"
        read -r vmlinuz initrd <<EOF
$(search_kernel "$tmp" | head -n 1)
EOF
        if [ -f "$vmlinuz" ] && [ -f "$initrd" ]; then
            re install -v -m 644 "$vmlinuz" "$TFTP_DIR/ltsp/$img_name/vmlinuz"
            re install -v -m 644 "$initrd" "$TFTP_DIR/ltsp/$img_name/initrd.img"
        else
            warn "Could not locate vmlinuz and initrd.img in $img_src"
        fi
        # Unmount everything and continue with the next image
        at_exit -EXIT
    done
}
