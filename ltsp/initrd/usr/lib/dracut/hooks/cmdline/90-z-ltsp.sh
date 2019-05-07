#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Hook for dracut.

# Work around https://github.com/dracutdevs/dracut/issues/539
if grep -qsw 'root=/dev/nbd0' /proc/cmdline; then
    echo 'nbd-client -c /dev/nbd0' > $hookdir/initqueue/finished/nbdroot.sh
fi
# Add proxyDHCP support
mv /usr/sbin/dhclient-script /usr/sbin/dhclient-script-real
ln -s dhclient-script-ltsp /usr/sbin/dhclient-script
# Avoid delays - TODO: remove
mv /usr/sbin/rdsosreport /usr/sbin/rdsosreport-real
