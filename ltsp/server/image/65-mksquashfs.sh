# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

mksquashfs_main() {
    export "_DST_DIR=$_DST_DIR"
    debug_shell
    # Unmount everything and continue with the next image
    rw at_exit -EXIT
}
