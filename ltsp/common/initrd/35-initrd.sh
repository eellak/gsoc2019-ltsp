# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create the additional LTSP initrd image at $TFTP_DIR/ltsp/ltsp.img
# Vendors can add to $_DST_DIR between initrd_main and cpio_main

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
    # The run directory will be moved to /run/ltsp/client
    re mkdir -p "$_DST_DIR/usr/share/ltsp/run"
    re cp -a "$_LTSP_DIR/client" "$_LTSP_DIR/common" "$_LTSP_DIR/ltsp" \
        "$_DST_DIR/usr/share/ltsp/"
    re mkdir -p "$_DST_DIR/conf/conf.d"
    # Busybox doesn't support ln -r
    re ln -s /usr/share/ltsp/client/initrd-bottom/initramfs-tools/ltsp-hook.conf \
        "$_DST_DIR/conf/conf.d/ltsp.conf"
    if [ -f /etc/ltsp/client.conf ]; then
        # TODO: or possibly in the initrd-bottom dir...
        re cp -a / etc/ltsp/client.conf "$_DST_DIR/usr/share/ltsp/run/"
    fi
    # Copy server public ssh keys; prepend "server" to each entry
    rw sed "s/^/server /" /etc/ssh/ssh_host_*_key.pub > "$_DST_DIR/usr/share/ltsp/client/login/ssh_known_hosts"
}
