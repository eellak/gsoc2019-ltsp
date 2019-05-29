# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create the additional LTSP initrd image at $TFTP_DIR/ltsp/ltsp.img

initrd_cmdline() {
    local scripts args

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
    run_main_functions "$scripts" "$@"
}

initrd_main() {
    local tmp script

    # It's simpler to copy everything into a temp dir before calling cpio
    tmp=$(mktemp -d)
    re cp -a "$_SRC_DIR/initrd/." "$tmp/"
    re cp -a "$_SRC_DIR/ltsp.sh" "$tmp/ltsp/"
    re mkdir -p "$tmp/ltsp/applets/"
    re cp -a "$_SRC_DIR/applets/ltsp" "$tmp/ltsp/applets/"
    # Users can override things from /etc/ltsp
    if [ -d /etc/ltsp/initrd ]; then
        re cp -a "/etc/ltsp/initrd/." "$tmp/"
    fi
    if [ -f /etc/ltsp/client.conf ]; then
        "$_SRC_DIR/applets/ltsp-initrd/ini2sh.awk" </etc/ltsp/client.conf \
            >"$tmp/ltsp/applets/ltsp/05-client-conf.sh"
    fi
    # Syntax check all the shell scripts
    while read -r script <&3; do
        sh -n "$script" || die "Syntax error in initrd script: $script"
    done 3<<EOF
$(find "$tmp" -name '*.sh')
EOF
    # Create the initrd
    # TODO: too complicated, shows "blank line ignored", and doesn't run with busybox cpio:
    # find "$tmp/" ! -name ltsp.img | sed "s|^$tmp/||" | \
    #     cpio -D "$tmp" -oH newc --quiet | gzip > "$tmp/ltsp.img"
    re cd "$tmp"
    find . ! -name ltsp.img | cpio -oH newc | gzip > "$tmp/ltsp.img"
    re cd - >/dev/null
    re mkdir -p "$TFTP_DIR/ltsp"
    re mv "$tmp/ltsp.img" "$TFTP_DIR/ltsp/"
    re rm -r "$tmp"
    echo "Generated ltsp.img:"
    ls -l "$TFTP_DIR/ltsp/ltsp.img"
}
