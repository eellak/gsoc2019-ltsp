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
_VERSION="1.0"
LTSP_BASE="${LTSP_BASE:-/srv/ltsp}"
LTSP_TFTP="${LTSP_TFTP:-/srv/ltsp}"

ltsp_cmdline() {
    if [ "$_LTSP_APPLET" = "ltsp" ] && [ -z "$_SOURCED" ]; then
        while true; do
            case "$1" in
                -h|--help|"") applet_usage; exit 0 ;;
                -V|--version) applet_version; exit 0 ;;
                -*) die "Unknown option: $1" ;;
                *)  _APPLET="$1"
                    _LTSP_APPLET="ltsp-$_APPLET"
                    shift
                    break
                    ;;
            esac
        done
    fi
    test -d "$_SRC_DIR/applets/$_APPLET" ||
        die "LTSP applet doesn't exist: $_APPLET"
    # Normally run_main_functions below would call ltsp_main(), and the
    # next source_applet would be there; but the LTSP_SCRIPTS variable can't
    # stack, so run them serially, without providing an ltsp_main().
    run_main_functions "$@"
    test "$_LTSP_APPLET" = "ltsp" && return 0
    source_applet "$_APPLET" "$@"
    # All applets are required to have an entry function named applet_cmdline
    test -n "$_SOURCED" || applet_cmdline "$@"
}
