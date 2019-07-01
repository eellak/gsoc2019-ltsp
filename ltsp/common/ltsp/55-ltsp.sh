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
BASE_DIR="${BASE_DIR:-/srv/ltsp}"
EXPORT_DIR="${EXPORT_DIR:-/srv/ltsp}"
TFTP_DIR="${TFTP_DIR:-/srv/ltsp}"

ltsp_cmdline() {
    while true; do
        case "$1" in
            -b|--base-dir) BASE_DIR=$1; shift ;;
            -e|--export-dir) EXPORT_DIR=$1; shift ;;
            -h|--help|"") applet_usage; exit 0 ;;
            -t|--tftp-dir) TFTP_DIR=$1; shift ;;
            -V|--version) applet_version; exit 0 ;;
            -*) die "Unknown option: $1" ;;
            *)  _APPLET="$1"
                shift
                break
                ;;
        esac
    done
    # "$@" is the applet parameters; don't use it for the ltsp main functions
    run_main_functions "$_SCRIPTS"
    # We could put the rest of the code below in an ltsp_main() function,
    # but we want ltsp/scriptname_main()s to finish before any applet starts
    locate_applet_scripts "$_APPLET"
    # Remember, locate_applet_scripts has just updated $_SCRIPTS
    source_scripts "$_SCRIPTS"
    "$_APPLET_FUNCTION" "$@"
}
