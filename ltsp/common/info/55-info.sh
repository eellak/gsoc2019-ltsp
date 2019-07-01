# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Copy vmlinuz and initrd.img from image to TFTP

info_cmdline() {
    local args

    args=$(re getopt -n "ltsp $_APPLET" -o "hV" \
        -l "help,version" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -h|--help) applet_usage; exit 0 ;;
            -V|--version) applet_version; exit 0 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline" ;;
        esac
        shift
    done
    run_main_functions "$_SCRIPTS" "$@"
}

info_main() {
    local tmp img_src img img_name

    printf "CHROOTS:\n"
    list_img_names -c
    printf "\nVMs:\n"
    list_img_names -v
    printf "\nIMAGES:\n"
    list_img_names -i
}
