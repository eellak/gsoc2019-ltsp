# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

pam_main() {
    re /usr/share/ltsp/client/login/pwmerge -lq /etc/ltsp /etc /etc
    re /usr/share/ltsp/client/login/pamltsp install
}
