#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

usage() {
    printf 'Usage: %s [OPTIONS] image [MOUNTDEVICE]

Copy vmlinuz and initrd.img from some image or directory to TFTP.

Options:
  -n, --name  Specify the image name. Otherwise it is autodetected.
  -h, --help  Display a help message.
      --version  Display the version information.
' "$0"

Example:
    sudo ~/bin/ltsp-export-kernel /home/Public/VMs/bionic-mate-sch32/bionic-mate-sch32-flat.vmdk
}

die() {
    printf "$@" >&2
    exit 1
}

# Fedora-Workstation-Live-x86_64-29-1.2.iso
#   /isolinux/vmlinuz /isolinux/initrd.img
# debian-testing-amd64-DVD-1.iso
#   install.amd/vmlinuz install.amd/initrd.gz
# Ubuntu 18:
#   /casper/vmlinuz /casper/initrd
# Ubuntu 10, 12, 14, LinuxMint 19, Xubuntu 18:
#   /casper/vmlinuz /casper/initrd.lz
# Ubuntu 8:
#   /casper/vmlinuz /casper/initrd.gz
search_kernel() {
    # Column 1: the kernel file name, including wildcards.
    # Column 2: sed regex to calculate the initrd file name from the kernel.
    # Column 3: comment.
    search='
# Ubuntu live CDs ("", .lz, .gz)
    casper/vmlinuz s|vmlinuz|initrd|
    casper/vmlinuz s|vmlinuz|initrd.lz|
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
'
    while read -r vglob ireg; do
        # Ignore comments and empty lines
        if [ -z "$vglob" ] || [ "$vglob" = "#" ]; then
            continue
        fi
        # printf "\tvglob=%s\tireg=%s\n" "$glob" "$ireg"
        for vmlinuz in "$1/"$vglob "$1/boot/"$vglob; do
            test -f "$vmlinuz" || continue
            initrd=$(printf "%s" "$vmlinuz" | sed "$ireg")
            if [ "$vmlinuz" = "$initrd" ]; then
                printf "\tRegex returned the same file name, ignoring:\n" >&3
                printf "%s, %s, %s\n" "$vmlinuz" "$initrd" "$ireg" >&3
                continue
            fi
            if [ -f "$initrd" ]; then
                printf "%s\t%s\n" "$(ls "$vmlinuz")" "$(ls "$initrd")"
            else
                printf "FOUND: $vmlinuz, NOT FOUND: $initrd\n" >&3
            fi
        done | sort -rV
    done <<EOF
$search
EOF
}

prereq() {
    for cmd in nbd-client qemu-nbd; do
        command -v "$cmd" >/dev/null \
            || die "%s needs %s, please install it\n" "$0" "$cmd"
    done
    modprobe nbd || die "Failed to load the NBD module"
}

main() {
    img=$1
    dev=${2:-/dev/nbd3}
    prereq
    # Unmount $dev in case it was previously mounted
    qemu-nbd -d "$dev" >/dev/null
    qemu-nbd --read-only --connect="$dev" "$1" || die "qemu-nbd error"
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
        mkdir -p "/var/lib/tftpboot/ltsp/$imgn"
        read vmlinuz initrd <<EOF
$(search_kernel /mnt 3>/dev/null | head -n 1)
EOF
        if [ -n "$vmlinuz" ] && [ -n "$initrd" ]; then
            # ls -l --color "$vmlinuz" "$initrd"
            install -v -m 644 "$vmlinuz" "/var/lib/tftpboot/ltsp/$imgn/vmlinuz"
            install -v -m 644 "$initrd" "/var/lib/tftpboot/ltsp/$imgn/initrd.img"
        fi
        # read -p "Press enter to unmount everything: " dummy
        umount /mnt
    fi
    printf "To stop serving when done, run:
# systemctl restart nbd-server
lvchange -an /dev/mapper/*
qemu-nbd -d $dev
"
    # qemu-nbd -d "$dev" >/dev/null
}

case "$1" in
  --version) printf "1.0\n"; exit 0 ;;
  ''|-h|--help) usage; exit 0 ;;
esac

main "$@"
