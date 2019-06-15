# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

pam_main() {
    rw /run/ltsp/applets/init/pamssh install
    export LANG=el_GR.UTF-8
    rw openvt -c 2 nano /run/ltsp/applets/init/pamssh
    rw openvt -c 3 nano /etc/pam.d/common-auth
    rw openvt -c 4 nano /etc/pam.d/common-session
    rw openvt -c 5 bash -l
}
