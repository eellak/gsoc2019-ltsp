# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Constant variables may be set in any of the following steps:
# 1) user: environment, `VAR=value $LTSP_TOOL`
# 2) distro: 11-ltsp-distro.sh for all tools
# 3) upstream: 55-ltsp.sh for all tools
# 4) user: /etc/ltsp/ltsp.conf for all tools
# 5) user: /etc/ltsp/$LTSP_TOOL.conf for a specific tool
# 6) distro: 11-$LTSP_TOOL-distro.sh for a specific tool
# 7) upstream: 55-$LTSP_TOOL-distro.sh for a specific tool
# For proper ordering, upstream and distros should use `VAR=${VAR:-value}`.
# We're still in the "sourcing" phase, so subsequent scripts may even use the
# variables before the "execution" phase.
# 8) user: cmdline `$LTSP_TOOL --VAR=value`, evaluated at the execution phase
# Btw, to see all constants: grep -rIwoh '$[A-Z][_A-Z0-9]*' | sort -u

# Distributions should replace "1.0" below at build time using `sed`
LTSP_VERSION="1.0"
LTSP_BASE="${LTSP_BASE:-/opt/ltsp}"
LTSP_TFTP="${LTSP_TFTP:-/var/lib/tftpboot}"

# If the user provided .conf files, source them now
if [ -f "/etc/ltsp/ltsp.conf" ]; then
    # shellcheck disable=SC1090
    . "/etc/ltsp/ltsp.conf"
fi
if [ -f "/etc/ltsp/$LTSP_TOOL.conf" ]; then
    # shellcheck disable=SC1090
    . "/etc/ltsp/$LTSP_TOOL.conf"
fi

# Distributions may override upstream functions via subsequent scripts
main_ltsp() {
    source_tool "$LTSP_TOOL" "$@"
    # All tools are required to have a main
    main "$@"
}
