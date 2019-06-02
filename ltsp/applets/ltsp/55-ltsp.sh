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
IMAGE_DIR="${IMAGE_DIR:-/srv/ltsp/images}"
NFS_DIR="${NFS_DIR:-/srv/ltsp}"
TFTP_DIR="${TFTP_DIR:-/srv/ltsp}"

ltsp_cmdline() {
    local scripts applet_cmdline

    scripts="$1"; shift
    if [ "$_LTSP_APPLET" = "ltsp" ] && [ -z "$_SOURCED" ]; then
        while true; do
            case "$1" in
                -b|--base-dir) BASE_DIR=$1; shift ;;
                -h|--help|"") applet_usage; exit 0 ;;
                -i|--image-dir) IMAGE_DIR=$1; shift ;;
                -n|--nfs-dir) NFS_DIR=$1; shift ;;
                -t|--tftp-dir) TFTP_DIR=$1; shift ;;
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
    run_main_functions "$scripts" "$@"
    # We could put the rest of the code below in an ltsp_main() function,
    # but we want ltsp/scriptname_main()s to finish before any applet starts
    test "$_LTSP_APPLET" != "ltsp" || return 0
    scripts=$(list_applet_scripts "$_APPLET")
    source_scripts "$scripts"
    # All applets are required to have an entry function ${_APPLET}_cmdline
    # that takes the list of the applets scripts as the first parameter
    applet_cmdline=$(echo "${_APPLET}_cmdline" | sed 's/[^[:alnum:]]/_/g')
    test -n "$_SOURCED" || "$applet_cmdline" "$scripts" "$@"
}
