#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# All /usr/[s]bin/ltsp-* tools are symlinks to ltsp.sh, which serves as
# an entry point, sources the appropriate configuration and tool functions etc.
# This architecture makes it possible to avoid hardcoded paths like
#     . /usr/share/ltsp/ltsp-tool-functions.sh
# It also allows shell scripts to have a .sh extension for highlighting,
# while /usr/[s]bin/ltsp-* binaries not to have an extension.
# Some tools run inside the initramfs, so some functions need to be compatible
# with busybox.

aa_main() {
    # Always stop on unhandled errors
    set -e
    # Allow overriding LTSP_DIR and LTSP_TOOL
    if [ -z "$LTSP_DIR" ]; then
        LTSP_DIR=$(readlink -f "$0")
        LTSP_DIR=${LTSP_DIR%/*}
    fi
    test -z "$LTSP_TOOL" && LTSP_TOOL=${0##*/}
    source_tool "ltsp" "$@"
    # This calls 55-ltsp.sh>main_ltsp(), which will eventually run the tool
    run_main_functions "$@"
}

# TODO: do we need this?
boolean_is_true() {
    case "$1" in
       # Match all cases of true|y|yes
       [Tt][Rr][Uu][Ee]|[Yy]|[Yy][Ee][Ss]) return 0 ;;
       *) return 1 ;;
    esac
}

# Print a message to stderr if $LTSP_DEBUG is appropriately set
debug() {
    case ",$LTSP_DEBUG," in
        *",$LTSP_TOOL,"*|,1,|,true,)  ;;
        *)  return 0;
    esac
    warn "LTSP_DEBUG:" "$@"
}

# Print a message to stderr and exit with an error code
die() {
    warn "$@"
    # If called from subshells, this just exits the subshell
    exit 1
}

# POSIX recommends that printf is preferred over echo.
# But do offer a simple wrapper to avoid "%s\n" all the time.
echo() {
    printf "%s\n" "$*"
}

# Run all the main_script() functions we already sourced
run_main_functions() {
    local script

    # 55-ltsp-initrd.sh should be called as: main_ltsp_initrd
    while read -r script; do
        case ",$LTSP_SKIP_SCRIPTS," in
            *",$script,"*) debug "Skipping main of script: $script" ;;
            *) "main_$script" "$@" ;;
        esac
    done <<EOF
$(echo "$LTSP_SCRIPTS" | sed -e 's/.*\///' -e 's/[^[:alpha:]]*\([^.]*\).*/\1/g' -e 's/[^[:alnum:]]/_/g')
EOF
}

# Input: two optional `find` parameters and an ordered list of directories.
# Output: a list of files, including their paths, ordered by their basenames.
# Files with the same name in subsequent directories (even in subdirs)
# override previous ones.
# Restriction: directory and file names shouldn't contain \t or \n.
# Algorithm: create the list as three tab-separated columns, like:
#   99  file  /dir[/subdir]/file
# The first column is an increasing directory index.
# Then sort them in reverse order, and finally by file name,
# so that "--unique" keeps the last occurrence.
# TODO: use sort -V, version, somewhere, to allow script~before
run_parts_list() {
    local param1 param2 tab i d f

    # If the first parameter starts with "-", consider it a find parameter
    if [ "$1" != "${1#-}" ]; then
        param1=$1
        param2=$2
        shift 2
    else
        param1="-name"
        param2="[0-9]*"
    fi
    tab=$(printf "\t")
    i=10
    for d in "$@"; do
        test -d "$d" || continue
        # Don't quote $param1 in case more params are ever required
        find "$d" $param1 "$param2" -type f \
        | while IFS='' read -r f; do
            printf '%s\t%s\t%s\n' "$i" "${f##*/}" "$f"
        done
        i=$((i+1))
    done \
    | sort -r \
    | sort -t "$tab" -k 2,2 -u \
    | sed 's@[^\t]*\t[^\t]*\t@@'
}

source_tool() {
    local tool script

    tool=$1
    shift
    # One of the dirs must exist
    if [ ! -d "$LTSP_DIR/tools/$tool" ] && [ ! -d "/run/ltsp/tools/$tool" ]; then
        die "Not a directory: $LTSP_DIR/tools/$tool"
    fi
    # https://www.freedesktop.org/software/systemd/man/systemd.unit.html
    # Drop-in files in /etc take precedence over those in /run
    # which in turn take precedence over those in /usr.
    LTSP_SCRIPTS=$(run_parts_list "$LTSP_DIR/tools/$tool" \
    "/run/ltsp/tools/$tool" \
    "/etc/ltsp/tools/$tool")
    while read -r script; do
        debug "Sourcing: $script"
        # shellcheck disable=SC1090
        . "$script"
    done <<EOF
$LTSP_SCRIPTS
EOF
}

tool_usage() {
    man "$LTSP_TOOL"
}

tool_version() {
    echo "$LTSP_TOOL $LTSP_VERSION"
}

# Print a message to stderr
warn() {
    echo "$@" >&2
}

# Set LTSP_SKIP_SCRIPTS=ltsp to source without executing any tools
aa_main "$@"
