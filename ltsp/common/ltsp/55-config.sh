# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Functions related to LTSP configuration and environment variables

# Output the values of all the variables that match the expression
echo_values() {
    local var value

    for var in $(echo_vars "$1"); do
        eval "value=\$$var"
        echo "$var: $value"
    done
}

# Output the names of all the variables that match the expression
echo_vars() {
    local ex var value

    ex=$1
    while IFS="=" read -r var value; do
        eval "value=\$$var"
        test -n "$value" || continue
        echo "$var"
    done <<EOF
$(set | grep "$ex")
EOF
}

eval_ini() {
    local config applet

    config=${1:-/etc/ltsp/client.conf}
    applet=${2:-$_APPLET}
    eval "$(ini2sh "$config")" || die "Error while evaluating $config"
    re network_vars
    re section_call unnamed default "$MAC_ADDRESS" "$IP_ADDRESS"
    # MAC/IP sections are allowed to set HOSTNAME
    re section_call "$HOSTNAME"
    if [ "${applet:-ltsp}" != "ltsp" ]; then
        re section_call "$applet/default" "$applet/$MAC_ADDRESS" "$applet/$IP_ADDRESS" "$applet/$HOSTNAME"
    fi
}

# Convert an .ini file, like client.conf, to a shell sourceable file.
# The basic ideas are:
# [a1:b2:c3:d4:*:*] becomes a function: section_a1_b2_c3_d4____() {
# LIKE=old_monitor becomes a call: section_old_monitor
# And a section_call() function is implemented to use like:
#   section_call "unnamed"
#   section_call "default"
#   section_call "$mac"
#   section_call "$ip"
#   section_call "$hostname"
# Use lowercase in parameters.
# To name the functions something_* rather than section_*, use:
#   ini2sh -v prefix=something_
ini2sh() {
    re awk -f - "$1" <<"EOF"
BEGIN {
    if (prefix == "") {
        prefix="section_"
    } else {
        # Sanitize prefix passed in the cmdline
        prefix=tolower(prefix)
        gsub("[^a-z0-9]", "_", prefix)
    }
    # The sections list, used later on in section_call()
    list=""
    # Cope with directives above the [Default] section, which is a user error
    section_id=prefix "unnamed"
    print section_id "() {\n"\
        "# Prevent infinite recursion\n"\
        "test \"$" section_id "\" = 1 && return 0 || " section_id "=1"
}
{
if ($0 ~ /^[ ]*\[[^]]*\]/) {  # [Section]
    print "}\n"
    section=tolower($0)
    gsub("[][]", "", section)
    section_id=section
    section_id=prefix section_id
    gsub("[^a-z0-9]", "_", section_id)
    print section_id "() {\n"\
        "test \"$" section_id "\" = 1 && return 0 || " section_id "=1"
    # Append the appropriate case line
    list=list "\n            " section ")  " section_id " \"$@\" ;;"
} else if (tolower($0) ~ /^like *=/) {  # LIKE = xxx
    value=tolower($0)
    sub("like *= *", "", value)
    print prefix value
} else if ($0 ~ /^[a-zA-Z0-9_]* *=/) {  # VAR = xxx
    value=$0
    sub(" *= *", "=", value)  # remove spaces only around the first =
    print value
} else {
    print $0
}
}
END {
    print "}\n\n"\
        "# Example usage: " prefix "call \"unnamed\" \"default\" \"$MAC\" \"$IP\" \"$lower_hostname\"\n"\
        prefix "call() {\n"\
        "    local section\n"\
        "\n"\
        "    for section in \"$@\"; do\n"\
        "        case \"$section\" in\n"\
        "            unnamed)  " prefix "unnamed \"$@\" ;;"\
        list\
        "\n        esac\n"\
        "    done\n"\
        "}"
}
EOF
}

install_template() {
    local backup src dst sedp dstdir sname sext language

    if [ "$1" = "-b" ]; then
        backup=1
        shift
    else
        backup=
    fi
    src=$1
    dst=$2
    sedp=$3
    if [ -e "$dst" ] && [ "$OVERWRITE" != "1" ]; then
        die "Configuration file already exists: $dst
To overwrite it, run: ltsp --overwrite $_APPLET ..."
    fi
    dstdir=${dst%/*}
    re mkdir -p "$dstdir"
    # Prefer localized templates, if they exist.
    sname=${src%%.*}
    if [ "$sname" != "$src" ]; then
        sext=".${src#*.}"
    else
        unset sext
    fi
    language=${LANGUAGE:-$LANG}
    for language in "${language%%:*}" "${language%%.*}" "${language%%_*}" ""; do
        language=${language:+"-$language"}
        test -f "$_APPLET_DIR/$sname$language$sext" || continue
        if [ "$backup" = "1" ] && [ -f "$dst" ]; then
            re mv "$dst" "$dst.old"
        fi
        re sed "$sedp" "$_APPLET_DIR/$sname$language$sext" > "$dst"
        echo "Installed $_APPLET_DIR/$sname$language$sext in $dst"
        return 0
    done
    die "Template file $src not found."
}

kernel_vars() {
    # Exit if already evaluated
    test "$kernel_vars" = "1" && return 0 || kernel_vars=1

    # Extreme scenario: ltsp.image="/path/to ltsp.vbox=1"
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
                var=toupper(substr(varvalue, 1, eq-1))
                gsub("-", "_", var)
                value=substr(varvalue, eq+1)
                printf("%s=%s\n", var, value)
            }
        }
    }
    ' < /proc/cmdline)"
}

migrate_local_content() {
    local old new local_content above_content below_content

    old=$1
    new=$2
    test -f "$new" || die "migrate_local_content: $new not found"
    test -f "$old" || return 0
    local_content=$(re sed \
        '/^### BEGIN LOCAL CONTENT/,/^### END LOCAL CONTENT/!d' "$old")
    test -n "$local_content" || return 0
    # https://stackoverflow.com/questions/15184358
    above_content=$(re sed '/^### BEGIN LOCAL CONTENT/,$d' "$new" && echo EOF)
    above_content="${above_content%
EOF}"
    test -n "$above_content" || die "No ### BEGIN LOCAL CONTENT in $new"
    below_content=$(re sed '1,/^### END LOCAL CONTENT/d' "$new")
    test -n "$below_content" || die "No ### END LOCAL CONTENT in $new"
    re cat > "$new" <<EOF
$above_content
$local_content
$below_content
EOF
}

# We care about the IP/MAC used to connect to the LTSP server, not all of them
# To handle multiple MACs in client.conf, use LIKE=
network_vars() {
    test -n "$DEVICE" && test -n "$IP_ADDRESS" && test -n "$MAC_ADDRESS" &&
        return 0
    read -r GATEWAY DEVICE IP_ADDRESS <<EOF
$(re ip -o route get 192.168.67.1 |
    sed -n 's/.*via *\([0-9.]*\) .*dev \([^ ]*\) .*src *\([0-9.]*\) .*/\1 \2 \3/p')
EOF
    re test "GATEWAY=$GATEWAY" != "GATEWAY="
    re test "DEVICE=$DEVICE" != "DEVICE="
    re test "IP_ADDRESS=$IP_ADDRESS" != "IP_ADDRESS="
    read -r MAC_ADDRESS <<EOF
$(re ip -o link show dev "$DEVICE" |
    sed -n 's|.* link/ether \([0-9a-f:]*\) .*|\1|p')
EOF
    re test "MAC_ADDRESS=$MAC_ADDRESS" != "MAC_ADDRESS="
}

# Run directives like PRE_INIT_XORG="ln -sf ../ltsp/xorg.conf /etc/X11/xorg.conf"
run_directives() {
    local directives

    directives=$(echo_values "$1")
    test -n "$directives" || continue
    debug "Running $1: $directives"
    re eval "$directives"
}

# Used by install_template
textif() {
    if [ "${1:-0}" != "0" ]; then
        echo "$2"
    else
        echo "$3"
    fi
}
