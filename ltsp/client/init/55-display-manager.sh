# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Handle tasks related to display managers

display_manager_main() {
    if is_command lightdm; then
        mkdir -p /etc/lightdm/lightdm.conf.d
        echo "# Work around https://github.com/CanonicalLtd/lightdm/issues/49
[Seat:*]
greeter-show-manual-login = true" > /etc/lightdm/lightdm.conf.d/ltsp.conf
    fi
}
