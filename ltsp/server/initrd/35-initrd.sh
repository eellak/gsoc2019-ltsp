# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create the additional LTSP initrd image at $TFTP_DIR/ltsp/ltsp.img
# Vendors can add to $_DST_DIR between initrd_main and finalize_main

initrd_cmdline() {
    local scripts args _DST_DIR

    scripts="$1"; shift
    args=$(re getopt -n "$_LTSP_APPLET" -o "hV" \
        -l "help,version" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -h|--help) applet_usage; exit 0 ;;
            -V|--version) applet_version; exit 0 ;;
            --) shift ; break ;;
            *) die "$_LTSP_APPLET: error in cmdline" ;;
        esac
        shift
    done
    _DST_DIR=$(re mktemp -d)
    run_main_functions "$scripts" "$@"
}

initrd_main() {
    re cp -a "$_SRC_DIR/initrd/." "$_DST_DIR/"
    re cp -a "$_SRC_DIR/ltsp.sh" "$_DST_DIR/ltsp/"
    re mkdir -p "$_DST_DIR/ltsp/applets/"
    re cp -a "$_SRC_DIR/applets/ltsp" "$_DST_DIR/ltsp/applets/"
    # Users can override things from /etc/ltsp
    if [ -d /etc/ltsp/initrd ]; then
        re cp -a "/etc/ltsp/initrd/." "$_DST_DIR/"
    fi
    if [ -f /etc/ltsp/client.conf ]; then
        "$_SRC_DIR/applets/ltsp-initrd/ini2sh.awk" </etc/ltsp/client.conf \
            >"$_DST_DIR/ltsp/applets/ltsp/05-client-conf.sh"
    fi
    # Copy server public ssh keys; prepend "server" to each entry
    rw sed "s/^/server /" /etc/ssh/ssh_host_*_key.pub > "$_DST_DIR/ltsp/applets/login/ssh_known_hosts"
}
