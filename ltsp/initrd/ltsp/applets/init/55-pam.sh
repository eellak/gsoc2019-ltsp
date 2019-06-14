# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

pam_main() {
    rw /run/ltsp/applets/init/pamssh install
    rw openvt nano /run/ltsp/applets/init/pamssh
    rw openvt nano /etc/pam.d/common-auth
    rw openvt bash -l
}
