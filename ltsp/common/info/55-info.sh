# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Display troubleshooting information about ltsp server and images

info_cmdline() {
    local args

    args=$(re getopt -n "ltsp $_APPLET" -o "" -l \
        "" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    run_main_functions "$_SCRIPTS" "$@"
}

info_main() {
    printf "CHROOTS:\n"
    list_img_names -c
    printf "\nVMs:\n"
    list_img_names -v
    printf "\nIMAGES:\n"
    list_img_names -i
}
