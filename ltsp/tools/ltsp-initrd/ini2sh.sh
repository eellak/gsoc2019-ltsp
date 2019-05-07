#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

call() {
    prefix="section"
    suffix=""
    for i in "$@"; do
        suffix=__$suffix
    done
    for i in "$@"; do
        prefix=${prefix}_$i
        suffix=${suffix#__}
        cmd="$prefix$suffix"
        if command -v "$cmd" >/dev/null; then
            echo "*** CALLING: $cmd ***"
            "$cmd"
        fi
    done
}

# Convert and source it
# ./ini2sh.awk /var/lib/tftpboot/ltsp/i386/lts.conf > /tmp/lts.sh && . /tmp/lts.sh

# Or just eval it
eval "$(./ini2sh.awk lts.conf)"

# Calculate vars
MAC="00:14:85:F3:25:F1"
IP="192.168.2.1"
HOSTNAME="FAT"

call unnamed
call default
call 74 d4 35 e9 b4 24
call 10 161 254 11
call alkis
echo "*** HERE ARE THE VARS: ***"
set | grep ^LTSP
return 0

# Call the functions
section_unnamed
section_default
# Call MAC functions. Each missing nibble is replaced by a SINGLE dash.
section_00__________
section_00_14________
section_00_14_85______
section_00_14_85_f3____
section_00_14_85_f3_25__
section_00_14_85_f3_25_f1
# Call IPv4 functions. Each missing byte is replaced by a SINGLE dash.
section_192______
section_192_168____
section_192_168_2__
section_192_168_2_1
# Call hostname function
section_fat

