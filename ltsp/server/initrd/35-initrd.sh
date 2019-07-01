# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create the additional LTSP initrd image at $TFTP_DIR/ltsp/ltsp.img
# Vendors can add to $_DST_DIR between initrd_main and finalize_main

initrd_cmdline() {
    local args _DST_DIR

    args=$(re getopt -n "ltsp $_APPLET" -o "hV" \
        -l "help,version" -- "$@")
    eval "set -- $args"
    while true; do
        case "$1" in
            -h|--help) applet_usage; exit 0 ;;
            -V|--version) applet_version; exit 0 ;;
            --) shift ; break ;;
            *) die "ltsp $_APPLET: error in cmdline" ;;
        esac
        shift
    done
    _DST_DIR=$(re mktemp -d)
    run_main_functions "$_SCRIPTS" "$@"
}

initrd_main() {
    re cp -a "$_LTSP_DIR/initrd/." "$_DST_DIR/"
    re cp -a "$_LTSP_DIR/ltsp.sh" "$_DST_DIR/ltsp/"
    re mkdir -p "$_DST_DIR/ltsp/applets/"
    re cp -a "$_LTSP_DIR/applets/ltsp" "$_DST_DIR/ltsp/applets/"
    # Users can override things from /etc/ltsp
    if [ -d /etc/ltsp/initrd ]; then
        re cp -a "/etc/ltsp/initrd/." "$_DST_DIR/"
    fi
    if [ -f /etc/ltsp/client.conf ]; then
        "$_LTSP_DIR/applets/ltsp-initrd/ini2sh.awk" </etc/ltsp/client.conf \
            >"$_DST_DIR/ltsp/applets/ltsp/05-client-conf.sh"
    fi
    # Copy server public ssh keys; prepend "server" to each entry
    rw sed "s/^/server /" /etc/ssh/ssh_host_*_key.pub > "$_DST_DIR/ltsp/applets/login/ssh_known_hosts"
}
