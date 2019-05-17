# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Create the additional LTSP initrd image at $TFTP/ltsp/ltsp.img

main() {
    local args tmp

    if ! args=$(getopt -n "$LTSP_TOOL" -o "hV" \
        -l "help,version" -- "$@")
    then
        exit 1
    fi
    eval "set -- $args"
    while true; do
        case "$1" in
            -h|--help) tool_usage; exit 0 ;;
            -V|--version) tool_version; exit 0 ;;
            --) shift ; break ;;
            *) die "$LTSP_TOOL: Internal error!" ;;
        esac
        shift
    done
    run_main_functions "$@"
}

main_ltsp_initrd() {
    local tmp script

    # It's simpler to copy everything into a temp dir before calling cpio
    tmp=$(mktemp -d)
    cp -a "$LTSP_DIR/initrd/." "$tmp/"
    cp -a "$LTSP_DIR/ltsp.sh" "$tmp/ltsp/"
    mkdir -p "$tmp/ltsp/tools/"
    cp -a "$LTSP_DIR/tools/ltsp" "$tmp/ltsp/tools/"
    # Users can override things from /etc/ltsp
    if [ -d /etc/ltsp/initrd ]; then
        cp -a "/etc/ltsp/initrd/." "$tmp/"
    fi
    if [ -f /etc/ltsp/ltsp-client.conf ]; then
        "$LTSP_DIR/tools/ltsp-initrd/ini2sh.awk" </etc/ltsp/ltsp-client.conf \
            >"$tmp/ltsp/tools/ltsp/ltsp-client.sh"
    fi
    # Syntax check all the shell scripts
    while read -r script <&3; do
        sh -n "$script" || die "Syntax error in initrd script"
    done 3<<EOF
$(find "$tmp" -name '*.sh')
EOF
    # Create the initrd
    # TODO: too complicated, shows "blank line ignored", and doesn't run with busybox cpio:
    # find "$tmp/" ! -name ltsp.img | sed "s|^$tmp/||" | \
    #     cpio -D "$tmp" -oH newc --quiet | gzip > "$tmp/ltsp.img"
    cd "$tmp"
    find . ! -name ltsp.img | cpio -oH newc | gzip > "$tmp/ltsp.img"
    cd - >/dev/null
    mkdir -p "$LTSP_TFTP/ltsp"
    mv "$tmp/ltsp.img" "$LTSP_TFTP/ltsp/"
    rm -r "$tmp"
    echo "Generated ltsp.img:"
    ls -l "$LTSP_TFTP/ltsp/ltsp.img"
}
