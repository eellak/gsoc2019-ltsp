#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Execution sequence:
# This main() > source ltsp/* (and config/vendor overrides)
# > ltsp_cmdline() > ltsp/scriptname_main()s > source applet/* (and overrides)
# > applet_cmdline() > applet/scriptname_main()s
main() {
    local scripts

    # Always stop on unhandled errors, http://fvue.nl/wiki/Bash:_Error_handling
    # Prefer `false || false` as it exits while `false && false` doesn't
    set -e

    # If we're being sourced, $0 doesn't point to ltsp.sh, which means we
    # can't locate applets etc. So the caller should manually set _SRC_DIR
    # to source ltsp, and _APPLET to additionally source an applet.
    if [ -n "$_SRC_DIR" ]; then
        _SOURCED=1
        debug "ltsp.sh sourced by $0"
        # Ignore all the caller command line parameters; they're not for us
        set --
        # Derive e.g. _LTSP_APPLET="ltsp-kernel" and _APPLET="kernel"
        if [ -n "$_APPLET" ]; then
            _LTSP_APPLET="ltsp-$_APPLET"
        else
            _LTSP_APPLET="ltsp"
            _APPLET="ltsp"
        fi
    else
        _SRC_DIR=$(re readlink -f "$0")
        _SRC_DIR=${_SRC_DIR%/*}
        _LTSP_APPLET="${0##*/}"
        _LTSP_APPLET="${_LTSP_APPLET%.sh}"
        if [ "$_LTSP_APPLET" = "ltsp" ]; then
            _APPLET=ltsp
        else
            _APPLET=${_LTSP_APPLET#ltsp-}
        fi
    fi
    scripts=$(list_applet_scripts "ltsp")
    source_scripts "$scripts"
    ltsp_cmdline "$scripts" "$@"
}

applet_usage() {
    local text

    text=$(re man "$_LTSP_APPLET")
    printf "Usage: %s\n\n%s\n\nOptions:\n%s\n" \
        "$(echo "$text" | sed -n '/^SYNOPSIS/,/^[^ ]/s/^\(       \|$\)//p')" \
        "$(echo "$text" | sed -n '/^DESCRIPTION/,/^[^ ]/s/^\(       \|$\)//p')" \
        "$(echo "$text" | sed -n '/^OPTIONS/,/^[^ ]/s/^     //p')"
}

applet_version() {
    echo "$_LTSP_APPLET $_VERSION"
}

# True if can chroot into this dir
can_chroot() {
    chroot "$1" true 2>/dev/null || return 1
}

# Print a message to stderr if $LTSP_DEBUG is appropriately set
# TODO: stderr might be redirected; if LTSP_DEBUG is set, backup stderr to
# stddebug (e.g. #5) initially, then redirect to it here.
debug() {
    case ",$LTSP_DEBUG," in
        *",$_APPLET,"*|,1,|,true,)  ;;
        *)  return 0;
    esac
    warn "LTSP_DEBUG:" "$@"
}

debug_shell() {
    local setsid

    # TODO: make this "repeat y/n" for security reasons, unless some
    # cmdline parameter is set. Also, check if stdin is valid (| pipe).
    ( umask 0077; set > /tmp/ltsp-env )
    warn "${1:-Dropping to a shell for troubleshooting, type exit to continue:}"
    # Debian defaults to SPLASH="true" and only disables it when
    # nosplash*|plymouth.enable=0 is passed in the cmdline
    if [ "$_APPLET" = "initrd-bottom" ] || [ "$_APPLET" = "init" ]; then
        if [ -x /bin/plymouth ] && pidof plymouthd >/dev/null; then
            warn "Stopping plymouth"
            rw plymouth quit
        fi
    fi
    # Use `setsid -c` to enable job control in the shell
    if is_command setsid; then
        setsid="setsid -c"
    else
        unset setsid
    fi
    if is_command bash; then
        $setsid bash
    else
        $setsid sh
    fi
}

# Print a message to stderr and exit with an error code.
# No need to pass a message if the failed command displays the error.
die() {
    if [ $# -eq 0 ]; then
        warn "Aborting ${_LTSP_APPLET:-LTSP}"
    else
        warn "$@"
    fi
    if [ "$_APPLET" = "initrd-bottom" ] || [ "$_APPLET" = "init" ]; then
        debug_shell
    fi
    # This notifies at_exit() to execute TERM_COMMANDS
    _DIED=1
    # If called from subshells, this just exits the subshell
    # With `set -e` though, it'll still exit on commands like x=$(false)
    exit 1
}

# POSIX recommends that printf is preferred over echo.
# But do offer a simple wrapper to avoid "%s\n" all the time.
echo() {
    printf "%s\n" "$*"
}

# On abnormal termination, we run both the term and exit commands.
# On normal termination, we only run the exit commands.
# For example, in initrd-bottom we don't want to unmount on normal exit.
at_exit() {
    # Don't stop on errors for the exit commands
    set +e
    # Stop trapping
    trap - 0 HUP INT QUIT SEGV PIPE TERM
    if [ "$1" = "-TERM" ] || [ "$_DIED" = "1" ]; then
        eval "$_TERM_COMMANDS"
    fi
    eval "$_EXIT_COMMANDS"
    # It's possible to manually call at_exit, run the commands, then
    # call exit_command again (e.g. `ltsp kernel img1 img2`).
    unset _TERM_COMMANDS
    unset _EXIT_COMMANDS
    unset _HAVE_TRAP
    set -e
}

# You may use `at_exit "rw command"`, but not `at_exit "re command"`
exit_command() {
    if [ "$_HAVE_TRAP" != "1" ]; then
        _HAVE_TRAP=1
        trap "at_exit -TERM" HUP INT QUIT SEGV PIPE TERM
        trap "at_exit -EXIT" EXIT
    fi
    if [ "$_APPLET" = "initrd-bottom" ]; then
        _TERM_COMMANDS="$*
$_TERM_COMMANDS"
    else
        _EXIT_COMMANDS="$*
$_EXIT_COMMANDS"
    fi
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
        command -v "$fun" >/dev/null || return $?
    done
}

kernel_variables() {
    test -n "$kernel_variables" && return 0

    # Exit if already evaluated
    kernel_variables=1
    # Extreme scenario: ltsp.loop="/path/to ltsp.vbox=1"
    # We don't want that to set VBOX=1.
    # Plan: replace spaces between quotes with \001,
    # then split the parameters using space,
    # then keep the ones that look like ltsp.var=value,
    # and finally restore the spaces.
    # TODO: should we add quotes when they don't exist?
    # Note that it'll be hard when var=value" with "quotes" inside "it
    eval "
$(awk 'BEGIN { FS=""; }
    {
        s=$0   # source
        d=""   # dest
        inq=0  # in quote
        split(s, chars, "")
        for (i=1; i <= length(s); i++) {
            if (inq && chars[i] == " ")
                d=d "\001"
            else {
                d=d "" chars[i]
                if (chars[i] == "\"")
                    inq=!inq
            }
        }
        split(d, vars, " ")
        for (i=1; i in vars; i++) {
            gsub("\001", " ", vars[i])
            if (tolower(vars[i]) ~ /^ltsp.[a-zA-Z][-a-zA-Z0-9_]*=/) {
                varvalue=substr(vars[i], 6)
                eq=index(varvalue,"=")
                var="LTSP_" toupper(substr(varvalue, 1, eq-1))
                gsub("-", "_", var)
                value=substr(varvalue, eq+1)
                printf("%s=%s\n", var, value)
            }
        }
    }
    ' < /proc/cmdline)"
}

# Run a command. Exit if it failed.
re() {
    rwr "$@" || die
}

# Run a command and return 0. Silently.
rs() {
    RWR_SILENCE=1 rwr "$@" || true
}

# Run a command silently and return $?. Used like `rsr cmd1 || cmd2`.
# This is just a shortcut for `cmd1 >/dev/null 2>&1 || cmd2`.
rsr() {
    RWR_SILENCE=1 rwr "$@" || return $?
}

# Run a command and return 0. Warn if it failed.
rw() {
    rwr "$@" || true
}

# Run a command. Warn if it failed. Return $?.
# Don't warn if $RWR_SILENCE is set, to easily implement rs() and rsr().
# Used like `rwr cmd1 || cmd2`.
rwr() {
    local want got

    # TODO: remove: echo "rwr $*" >&2
    if [ "$1" = "!" ]; then
        want=1
        shift
    else
        want=0
    fi
    got=0
    if [ -n "$RWR_SILENCE" ]; then
        "$@" >/dev/null 2>&1 || got=$?
    else
        "$@" || got=$?
    fi
    # Failed if either of them is zero and the other non-zero
    if [ "$want" = 0 -a "$got" != 0 ] || [ "$want" != 0 -a "$got" = 0 ]; then
        test -n "$RWR_SILENCE" || warn "LTSP command failed: $*"
    fi
    return $got
}

# Run all the main_script() functions we already sourced
run_main_functions() {
    local scripts script

    scripts="$1"; shift
    # 55-initrd.sh should be called as: initrd_main
    # <&3 is to allow scripts to use stdin instead of using the HEREDOC
    while read -r script <&3; do
        is_command "${script}_main" || continue
        case ",$LTSP_SKIP_SCRIPTS," in
            *",$script,"*) debug "Skipping main of script: $script" ;;
            *)  debug "Running main of script: $script"
                "${script}_main" "$@"
                ;;
        esac
    done 3<<EOF
$(echo "$scripts" | sed -e 's/.*\///' -e 's/[^[:alpha:]]*\([^.]*\).*/\1/g' -e 's/[^[:alnum:]]/_/g')
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
# TODO: find can be replaced with `for x in $glob`, if needed for dracut
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

list_applet_scripts() {
    local applet script

    applet=$1
    shift
    # One of the dirs must exist
    if [ ! -d "$_SRC_DIR/applets/$applet" ] && [ ! -d "/run/ltsp/applets/$applet" ]; then
        die "LTSP applet doesn't exist: $_SRC_DIR/applets/$applet"
    fi
    # https://www.freedesktop.org/software/systemd/man/systemd.unit.html
    # Drop-in files in /etc take precedence over those in /run
    # which in turn take precedence over those in /usr.
    test -f "/etc/ltsp/$applet.conf" && echo "/etc/ltsp/$applet.conf"
    run_parts_list "$_SRC_DIR/applets/$applet" \
    "/run/ltsp/applets/$applet" \
    "/etc/ltsp/applets/$applet"
}

source_scripts() {
    local scripts script

    scripts=$1
    while read -r script <&3; do
        debug "Sourcing: $script"
        . "$script"
    done 3<<EOF
$scripts
EOF
}

# Print a message to stderr
warn() {
    echo "$@" >&2
}


main "$@"
