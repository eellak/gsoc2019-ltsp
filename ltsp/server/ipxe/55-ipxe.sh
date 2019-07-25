# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Install iPXE binaries and configuration in TFTP

BINARIES_URL=${BINARIES_URL:-https://github.com/ltsp/binaries/releases/latest/download}

ipxe_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "u:" -l \
        "binaries-url:" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -u|--binaries-url) shift; BINARIES_URL=$1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    test "$#" = "0" || usage 1
    run_main_functions "$_SCRIPTS" "$@"
}

ipxe_main() {
    local binary

    re mkdir -p "$TFTP_DIR/ltsp"
    install_template "ltsp.ipxe" "$TFTP_DIR/ltsp/ltsp.ipxe" "\
s|^/srv/ltsp|$BASE_DIR|g
"
    # Why memtest.0 from ipxe.org is preferred over the one from distributions:
    # https://lists.ipxe.org/pipermail/ipxe-devel/2012-August/001731.html
    for binary in memtest.0 memtest.efi snponly.efi undionly.kpxe; do
        if [ "$OVERWRITE" = "1" ] || [ ! -f "$TFTP_DIR/ltsp/$binary" ]; then
            re wget -nv "$BINARIES_URL/$binary"
        else
            echo "Skipping existing $TFTP_DIR/ltsp/$binary"
        fi
    done
    echo "Installed iPXE binaries and configuration in $TFTP_DIR/ltsp"
}
