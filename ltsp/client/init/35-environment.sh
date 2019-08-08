# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Set up essential environment variables

environment_main() {
    re detect_server
}

# To detect the server, we don't want to use the following:
#  - ROOTSERVER may be invalid in case of proxyDHCP.
#  - `ps -fC nbd-client` doesn't work as it's now a kernel thread.
#  - It may be available in /proc/cmdline, but it's complex to check
#    for all the variations of ip=, root=, netroot=, nbdroot= etc.
# So assume that the first TCP connection is to the server (NFS etc)
detect_server() {
    local cmd

    test -z "$SERVER" || return 0
    if is_command ss; then
        cmd="ss -tn"
    elif is_command netstat; then
        cmd="netstat -tn"
    elif is_command busybox; then
        cmd="busybox netstat -tn"
    else
        warn "Not found: ss, netstat, busybox!"
        unset cmd
    fi
    if [ -n "$cmd" ]; then
        SERVER=$(rw $cmd |
            sed -n 's/.*[[:space:]]\([0-9.:]*\):\([0-9]*\)[^0-9]*/\1/p' |
            head -1)
    fi
    # Otherwise, default to the gateway or 192.168.67.1
    SERVER=${SERVER:-$GATEWAY}
    SERVER=${SERVER:-192.168.67.1}
}

