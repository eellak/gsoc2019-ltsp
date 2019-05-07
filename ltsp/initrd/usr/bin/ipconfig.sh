#!/bin/sh
# This file is part of masd, https://masd.github.io
# Copyright 2018 the masd team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later
# Override /bin/ipconfig to workaround networking issues.

# Start by calling the original ipconfig:
/bin/ipconfig.real "$@"

# Source its output:
for netconf in /run/net-*.conf; do
    test -f "$netconf" || panic 'No net-*.conf'
done
. "$netconf"

# If ROOTPATH is set, a real DHCP server is used, so just exit
test -n "$ROOTPATH" && exit 0

# Export the kernel cmdline masd.* variables
for v in $(cat /proc/cmdline); do
    test "$v" = "${v#masd.}" && continue
    v=${v#masd.}
    export $(echo "$v" | awk -F= '{ OFS=FS; $1=toupper($1); print }')
done

sed "s@^ROOTPATH=.*@ROOTPATH=$ROOTPATH@" -i "$netconf"
sed "s@^ROOTSERVER=.*@ROOTSERVER=$ROOTSERVER%$DEVICE@" -i "$netconf"

while ip a | grep -q "link tentative"; do
    printf "Waiting for ipv6 link...\n"
    sleep 1
done

# printf "Here's a shell:\n"; /bin/sh
