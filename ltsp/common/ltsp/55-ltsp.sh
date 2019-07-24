# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Handle the pre-applet part of the ltsp command line

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
BASE_DIR=${BASE_DIR:-/srv/ltsp}
TFTP_DIR=${TFTP_DIR:-/srv/tftp/ltsp}
HOME_DIR=${HOME_DIR:-/home}

ltsp_cmdline() {
    local args show_help help_param

    args=$(re getopt -n "ltsp" -o "+b:h::m:o::t:V" -l \
        "base-dir:,help::,home-dir:,overwrite::,tftp-dir:,version" -- "$@")
    eval "set -- $args"
    show_help=0
    help_param=
    while true; do
        case "$1" in
            -b|--base-dir) shift; BASE_DIR=$1 ;;
            -h|--help) shift; help_param=$1; show_help=1 ;;
            -m|--home-dir) shift; HOME_DIR=$1 ;;
            -o|--overwrite) shift; OVERWRITE=${1:-1} ;;
            -t|--tftp-dir) shift; TFTP_DIR=$1; ;;
            -V|--version) version; exit 0 ;;
            --) shift; break ;;
            *) die "ltsp: error in cmdline: $*" ;;
        esac
        shift
    done
    # Support `ltsp --help`, `ltsp --help=applet` and `ltsp --help applet`
    if [ "$show_help" = "1" ]; then
        if [ -n "$help_param" ] || [ -n "$1" ]; then
            _APPLET=${help_param:-$1}
        fi
        usage 0
    elif [ -z "$1" ]; then
        # Plain `ltsp` shows usage and exits with error
        usage 1
    fi
    # "$@" is the applet parameters; don't use it for the ltsp main functions
    run_main_functions "$_SCRIPTS"
    _APPLET="$1"; shift
    # We could put the rest of the code below in an ltsp_main() function,
    # but we want ltsp/scriptname_main()s to finish before any applet starts
    locate_applet_scripts "$_APPLET"
    # Remember, locate_applet_scripts has just updated $_SCRIPTS
    source_scripts "$_SCRIPTS"
    "$_APPLET_FUNCTION" "$@"
}
