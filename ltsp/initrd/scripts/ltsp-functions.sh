# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Sourced by LTSP initramfs scripts.

. /scripts/functions

log() {
    printf "\n\t    #### [LTSP]: "
    printf "$@"
}

# Export the kernel cmdline ltsp.* variables
kernel_variables() {
    for v in $(cat /proc/cmdline); do
        test "$v" = "${v#ltsp.}" && continue
        v=${v#ltsp.}
        export $(echo "$v" | awk -F= '{ OFS=FS; $1=toupper($1); print }')
    done
}

log "Running $0\n"
