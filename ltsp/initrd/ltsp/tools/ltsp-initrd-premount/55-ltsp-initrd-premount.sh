# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# This hook is supposed to run after networking is configured and before root
# is mounted, in order to:
#  * Repair wrong networking, e.g. ProxyDHCP
#     - Meh, not needed with iPXE; only with syslinux/IPAPPEND 2
#  * Evaluate IP/MAC/HOSTNAME sections of lts.conf
#  * Example: One could set SERVER=ip in lts.conf, to choose where nbd would connect!
# For initramfs tools, networking isn't yet configured, but it's OK to call
# configure_networking at this point.
# Now... in which cases do we want to run ltsp-client without networking?!
#  * Roaming laptop without networking. Local accounts AND home!

main() {
    warn "Starting $LTSP_TOOL"
    debug_shell
    case "$ROOT" in
        /dev/nbd*)
            patch_nbd
            ;;
        /dev/etherd/*)
            configure_aoe
            ;;
    esac
}

patch_nbd() {
    # Work around https://github.com/NetworkBlockDevice/nbd/issues/87
    # and https://github.com/NetworkBlockDevice/nbd/issues/99
    if grep -qs 'systemd-mark$' /scripts/local-top/nbd; then
        sed "s/systemd-mark$/& -b 512; blockdev --rereadpt \$nbdrootdev/" -i /scripts/local-top/nbd
    fi
}

# TODO: call configure_networking; we'll need it anyway for getltscfg and sshfs
configure_aoe() {
    local i interfaces

    # Wait for the network interfaces to become available
    i=0
    while i=$((i+1)); do
        interfaces=$(ip -oneline link show | sed -n '/ether/s/[0-9 :]*\([^:]*\).*/\1/p')
        if [ -n "$interfaces" ]; then
            break
        elif [ $i -ge 10 ]; then
            # After a while, give a shell to the user in case he can fix it
            debug_shell "No network interfaces found"
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
    while i=$((i+1)); do
        if ip -oneline link show up | grep -vw lo | grep -q LOWER_UP; then
            break
        elif [ $i -ge 4 ]; then
            # After a while, give a shell to the user in case he can fix it
            debug_shell "No network interfaces are up"
            i=0
        else
            sleep 1
        fi
    done
    modprobe aoe
    udevadm settle || true
}
