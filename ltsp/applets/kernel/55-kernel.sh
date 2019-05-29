# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Copy kernel from image to TFTP

kernel_cmdline() {
    local scripts args

    scripts="$1"; shift
    args=$(re getopt -n "$_LTSP_APPLET" -o "hi:k:n:p:V" \
        -l "help,initrd:,kernel:,name:,partition:,version" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -h|--help) applet_usage; exit 0 ;;
            -i|--initrd) shift; INITRD="$1" ;;
            -k|--kernel) shift; KERNEL="$1" ;;
            -n|--name) shift; NAME="$1" ;;
            -p|--partition) shift; PARTITION="$1" ;;
            -V|--version) applet_version; exit 0 ;;
            --) shift; break ;;
            *) die "$_LTSP_APPLET: error in cmdline" ;;
        esac
        shift
    done
    run_main_functions "$scripts" "$@"
}

kernel_main() {
    local img loop tmp

    die "OK this is kernel_main, time to die"
    tmp=$(re mktemp -d)
    trap_commands="rmdir $tmp"
    while read -r dir <&3; do
        if [ ! -d "$dir" ]; then
            true
        fi
        # Now img is a dir
        partprobe "$dev" 2>/dev/null
        # 83 Linux=MBR, Linux filesystem=GPT, 17 Hidden HPFS/NTFS=iso, 0 Empty=iso
        devp=$(sfdisk -l "$dev" | awk \
            '/83 Linux|Linux filesystem|17 Hidden HPFS|0 Empty/ { print $1; exit }')
        # If it doesn't have partitions, maybe it's an old .iso or a partition
        devp=${devp:-$dev}
        # printf "Device/partition=%s\n" "$devp"
        if [ -n "$devp" ] && mount -o loop,ro "$devp" /mnt; then
            # Keep the image name
            imgn=${img##*/}
            imgn=${imgn%.*}
            imgn=${imgn%-flat}
            devn=${dev##*/}
            mkdir -p "/srv/ltsp/ltsp/$imgn"
            read vmlinuz initrd <<EOF
$(search_kernel /mnt | head -n 1)
EOF
            if [ -n "$vmlinuz" ] && [ -n "$initrd" ]; then
                # ls -l --color "$vmlinuz" "$initrd"
                install -v -m 644 "$vmlinuz" "/srv/ltsp/ltsp/$imgn/vmlinuz"
                install -v -m 644 "$initrd" "/srv/ltsp/ltsp/$imgn/initrd.img"
            fi
            # read -p "Press enter to unmount everything: " dummy
            umount /mnt
        fi
    done 3<<EOF
$(list_images "$@")
EOF
    unset trap_commands
}

search_kernel() {
    local dir vglob ireg vmlinuz initrd

    dir=$1
    while read -r vglob ireg <&3; do
        # Ignore comments and empty lines
        if [ -z "$vglob" ] || [ "$vglob" = "#" ]; then
            continue
        fi
        # debug "\tvglob=%s\tireg=%s\n" "$glob" "$ireg"
        for vmlinuz in "$dir/"$vglob "$dir/boot/"$vglob; do
            test -f "$vmlinuz" || continue
            initrd=$(printf "%s" "$vmlinuz" | sed "$ireg")
            if [ "$vmlinuz" = "$initrd" ]; then
                debug "\tRegex returned the same file name, ignoring:\n"
                debug "%s, %s, %s\n" "$vmlinuz" "$initrd" "$ireg"
                continue
            fi
            if [ -f "$initrd" ]; then
                printf "%s\t%s\n" "$(ls "$vmlinuz")" "$(ls "$initrd")"
            else
                debug "FOUND: $vmlinuz, NOT FOUND: $initrd\n"
            fi
        done | sort -rV
    done 3<<EOF
# Column 1: the kernel file name, including wildcards.
# Column 2: sed regex to calculate the initrd file name from the kernel.
# Column 3: comment.
# Ubuntu 18 live CDs:
    casper/vmlinuz s|vmlinuz|initrd|
# Ubuntu 10, 12, 14, LinuxMint 19, Xubuntu 18:
    casper/vmlinuz s|vmlinuz|initrd.lz|
# Ubuntu 8 live CD:
    casper/vmlinuz s|vmlinuz|initrd.gz|
# debian-testing-amd64-DVD-1.iso
    install.amd/vmlinuz s|vmlinuz|initrd.gz|
# Fedora-Workstation-Live-x86_64-29-1.2.iso
    isolinux/vmlinuz s|vmlinuz|initrd.img|
# deb-based, prefer symlinks, see: man kernel-img.conf
    vmlinuz s|vmlinuz|initrd.img|
# deb-based installations
    vmlinuz-* s|vmlinuz|initrd.img|
# CentOS/Gentoo installations (vmlinuz-VER => initramfs-VER.img)
    vmlinuz-* s|vmlinuz-\(.*\)|initramfs-\1.img|
# Tinycorelinux
    vmlinuz s|vmlinuz|core.gz|
EOF
}
