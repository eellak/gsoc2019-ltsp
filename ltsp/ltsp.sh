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
    # Always stop on unhandled errors, http://fvue.nl/wiki/Bash:_Error_handling
    # We use this quirk: `false && false; echo ok` ==> doesn't exit
    set -e
    trap "trap_cleanup" 0 HUP INT QUIT SEGV PIPE TERM
    # Allow overriding LTSP_DIR and LTSP_TOOL
    if [ -z "$LTSP_DIR" ]; then
        LTSP_DIR=$(readlink -f "$0")
        LTSP_DIR=${LTSP_DIR%/*}
    fi
    test -z "$LTSP_TOOL" && LTSP_TOOL=${0##*/}
    source_tool "ltsp" "$@"
    # This calls 55-ltsp.sh>main_ltsp(), which will eventually run the tool
    run_main_functions "$@"
    trap - 0 HUP INT QUIT SEGV PIPE TERM
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

debug_shell() {
    ( umask 0077; set > /tmp/ltsp-env-$$ )
    warn "${1:-Dropping to a shell for troubleshooting, type exit to continue:}"
    if is_command bash; then
        bash
    else
        sh
    fi
}

# Print a message to stderr and exit with an error code.
# No need to pass a message if the failed command displays the error.
die() {
    trap - 0 HUP INT QUIT SEGV PIPE TERM
    if [ $# -eq 0 ]; then
        warn "ERROR in ${LTSP_TOOL:-LTSP}!"
        debug_shell
    else
        warn "$@"
    fi
    # If called from subshells, this just exits the subshell
    exit 1
}

# POSIX recommends that printf is preferred over echo.
# But do offer a simple wrapper to avoid "%s\n" all the time.
echo() {
    printf "%s\n" "$*"
}

# Check if parameter is a command; `command -v` isn't allowed by POSIX
is_command() {
    local fun

    if [ -z "$is_command" ]; then
        command -v is_command >/dev/null ||
            die "Your shell doesn't support command -v"
        is_command=1
    fi
    for fun in "$@"; do
        command -v "$fun" >/dev/null || return 1
    done
}

# TODO: do we need this here?
# Export the kernel cmdline ltsp.* variables
kernel_variables() {
    local v

    for v in $(cat /tmp/cmdline); do
        test "$v" = "${v#ltsp.}" && continue
        v=${v#ltsp.}
        export "$(echo "$v" | awk -F= '{ OFS=FS; $1=toupper($1); print }')"
    done
}

# Run a command and fall to a debug shell if it returns false
must() {
    local want got

    if [ "$1" = "!" ]; then
        want=1
        shift
    else
        want=0
    fi
    while true; do
        if "$@"; then
            got=0
        else
            got=1
        fi
        if [ "$want" = "$got" ]; then
            break
        else
            debug_shell "LTSP command failed: $*
Type 'exit' to retry, or 'exit 1' to terminate" || die
        fi
    done
}

# Run all the main_script() functions we already sourced
run_main_functions() {
    local script

    # 55-ltsp-initrd.sh should be called as: main_ltsp_initrd
    # <&3 is to allow scripts to use stdin instead of using the HEREDOC
    while read -r script <&3; do
        is_command "main_$script" || continue
        case ",$LTSP_SKIP_SCRIPTS," in
            *",$script,"*) debug "Skipping main of script: $script" ;;
            *)  debug "Running main of script: $script"
                "main_$script" "$@"
                ;;
        esac
    done 3<<EOF
$(echo "$LTSP_SCRIPTS" | sed -e 's/.*\///' -e 's/[^[:alpha:]]*\([^.]*\).*/\1/g' -e 's/[^[:alnum:]]/_/g')
EOF
}

# TODO: dracut doesn't have find, but it can be crudely simulated with bash
# Currently simulating only: find $DIR -type f
if ! is_command find; then
find() {
    bash -c 'shopt -s globstar; for f in '"$1"'/**; do if [ "${f%.sh}" != "$f" ]; then echo "$f"; fi; done | sort'
}
fi

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
    while read -r script <&3; do
        debug "Sourcing: $script"
        . "$script"
    done 3<<EOF
$LTSP_SCRIPTS
EOF
}

tool_usage() {
    man "$LTSP_TOOL"
}

tool_version() {
    echo "$LTSP_TOOL $LTSP_VERSION"
}

trap_cleanup() {
    # Stop trapping
    trap - 0 HUP INT QUIT SEGV PIPE TERM
    die
}

# Print a message to stderr
warn() {
    echo "$@" >&2
}


# Set LTSP_SKIP_SCRIPTS=ltsp to source without executing any tools
# Set LTSP_MAIN=true to source only this file
"${LTSP_MAIN:-aa_main}" "$@"
