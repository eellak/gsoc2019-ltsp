# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Work around various initramfs-tools issues

main() {
    warn "Starting $LTSP_TOOL"
    case "$ROOT" in
        /dev/nbd*)
            patch_nbd
            ;;
        /dev/etherd/*)
            . /scripts/functions
            configure_aoe
            ;;
    esac
}

patch_nbd() {
    # Work around https://github.com/NetworkBlockDevice/nbd/issues/87
    # Additionally, partprobe may be needed when nbd is not a single partition
    if grep -qs 'systemd-mark$' /scripts/local-top/nbd; then
        sed 's/systemd-mark$/& -b 512; blockdev --rereadpt $nbdrootdev/' -i /scripts/local-top/nbd
    fi
}

configure_aoe() {
    local i interfaces

    # Wait for the network interfaces to become available
    i=0
    while i=$(($i+1)); do
        interfaces=$(ip -oneline link show | sed -n '/ether/s/[0-9 :]*\([^:]*\).*/\1/p')
        if [ -n "$interfaces" ]; then
            break
        elif [ $i -ge 10 ]; then
            # After a while, give a shell to the user in case he can fix it
            panic "No network interfaces found"
            i=0
        else
            sleep 1
        fi
    done
    # For AoE to work, interfaces need to be up, but don't need IPs
    for i in $interfaces; do
        ip link set dev "$i" up
    done
    # Wait for a network interface to be up
    i=0
    while i=$(($i+1)); do
        if ip -oneline link show up | grep -vw lo | grep -q LOWER_UP; then
            break
        elif [ $i -ge 4 ]; then
            # After a while, give a shell to the user in case he can fix it
            panic "No network interfaces are up"
            i=0
        else
            sleep 1
        fi
    done
    modprobe aoe
    udevadm settle || true
}
