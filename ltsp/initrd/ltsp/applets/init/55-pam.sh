# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

pam_main() {
    local search replace

    # This is Debian/Ubuntu specific:
    search="^auth\t\[success=1 default=ignore\]\tpam_unix.so nullok_secure$"
    replace="auth\t\[success=2 default=ignore\]\tpam_unix.so nullok_secure\n\
auth\t\[success=1 default=ignore\]\tpam_exec.so expose_authtok seteuid stdout quiet /run/ltsp/applets/init/pamssh"
    sed "s|$search|$replace|" -i /etc/pam.d/common-auth
    grep -qw "pamssh" /etc/pam.d/common-auth ||
        die "Could not configure pam for ssh authentication!"
    openvt nano /run/ltsp/applets/init/pamssh
    openvt nano /etc/pam.d/common-auth
    openvt bash -l
}
