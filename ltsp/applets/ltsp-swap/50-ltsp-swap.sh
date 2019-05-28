#!/bin/sh
#
#  Copyright (c) 2006 Vagrant Cascadian <vagrant@freegeek.org>
#
#  2006, Oliver Grawert <ogra@canonical.com>
#  2008, Warren Togami <wtogami@redhat.com>
#        Vagrant Cascadian <vagrant@freegeek.org>
#        Eric Harrison <eharrison@k12linux.mesd.k12.or.us>
#  2012, Alkis Georgopoulos <alkisg@gmail.com>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, you can find it on the World Wide
#  Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
#  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#

# Generates a swap file to be exported with nbd-server.
#
# When called with no parameters, it assumes that it was ran from inetd,
# and it launches nbd-server in order to serve it.
# An inetd configuration line like the following is needed in that case:
# 9572 stream tcp nowait nobody /usr/sbin/tcpd /usr/sbin/nbdswapd
#
# When called with one parameter, it assumes that it was ran from nbd-server,
# so it just creates the specified swap file and exits.
# The nbd-server configuration section is expected to look similar to this:
# [swap]
# exportname = /tmp/nbd-swap/%s
# prerun = nbdswapd %s
# postrun = rm -f %s

# Fail on error, to notify nbd-server that the swap file wasn't created.
set -e

# Default sparse swapfile size, in MB
SIZE=512
# Default to running mkswap 
RUN_MKSWAP=true
# Allow overriding the defaults from a configuration file
if [ -f /etc/ltsp/nbdswapd.conf ]; then
    . /etc/ltsp/nbdswapd.conf
fi

# Abort if liveimg
if grep -q "liveimg" /proc/cmdline; then
    exit 1
fi

test $# -eq 0 && inetd=true
if [ -n "$inetd" ]; then
    if [ -n "$SWAPDIR" ]; then
        if [ -d "$SWAPDIR" ] && [ -w "$SWAPDIR" ]; then
            TEMPFILE_OPTS="${SWAPDIR}/XXXXXX"
        else
            echo "ERROR: not a directory or not writeable: $SWAPDIR" >&2
            exit 1
        fi
    fi

    if [ -z "$SWAP" ]; then
        SWAP=$(mktemp $TEMPFILE_OPTS)
    fi    
else
    SWAP="$1"
    SWAPDIR=${SWAP%/*}
    test -d "$SWAPDIR" || mkdir -p "$SWAPDIR"
fi

# Remove the file in case it already exists and it's in use by another process
rm -f "$SWAP"
# generate the swap file
dd if=/dev/zero of="$SWAP" bs=1M count=0 seek="$SIZE" 2> /dev/null
chmod 600 "$SWAP"

if [ "$RUN_MKSWAP" = "true" ]; then
    mkswap "$SWAP" > /dev/null
fi

if [ -n "$inetd" ]; then
    # start the swap server
    nbd-server 0 "$SWAP" $NBD_SERVER_OPTS -C /dev/null > /dev/null 2>&1 || true

    # clean up the swap file
    rm -f "$SWAP"
else
    # NBD server doesn't always call the postrun action that removes the swap:
    # https://github.com/NetworkBlockDevice/nbd/issues/47
    # To work around that, delete the file after 10 seconds.
    # The kernel won't remove it from disk while nbd-server is still using it.
    # The stdio redirection helps in daemonizing the task.
    # TODO: if nbd-client reconnections ever work properly, we would then like
    # to export the same file per client without removing/erasing it first.
    ( sleep 10; rm -f "$SWAP" ) >/dev/null 2>&1 &
fi
