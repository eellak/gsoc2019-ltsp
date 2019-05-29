# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Constant variables may be set in any of the following steps:
# 1) user: environment, `VAR=value $_APPLET`
# 2) distro: 11-ltsp-distro.sh for all applets
# 3) upstream: 55-ltsp.sh for all applets
# 4) user: /etc/ltsp/ltsp.conf for all applets
# 5) user: /etc/ltsp/$_APPLET.conf for a specific applet
# 6) distro: 11-$_APPLET-distro.sh for a specific applet
# 7) upstream: 55-$_APPLET-distro.sh for a specific applet
# For proper ordering, upstream and distros should use `VAR=${VAR:-value}`.
# We're still in the "sourcing" phase, so subsequent scripts may even use the
# variables before the "execution" phase.
# 8) user: cmdline `$_APPLET --VAR=value`, evaluated at the execution phase
# Btw, to see all constants: grep -rIwoh '$[A-Z][_A-Z0-9]*' | sort -u

# Distributions should replace "1.0" below at build time using `sed`
LTSP_VERSION="1.0"
LTSP_BASE="${LTSP_BASE:-/srv/ltsp}"
LTSP_TFTP="${LTSP_TFTP:-/srv/ltsp}"

# If the user provided .conf files, source them now
if [ -f "/etc/ltsp/ltsp.conf" ]; then
    . "/etc/ltsp/ltsp.conf"
fi
if [ -f "/etc/ltsp/$_APPLET.conf" ]; then
    . "/etc/ltsp/$_APPLET.conf"
fi
