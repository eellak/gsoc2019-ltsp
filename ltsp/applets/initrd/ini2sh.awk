#!/usr/bin/awk -f
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Convert an .ini file, like client.conf, to a shell sourceable file.
# The basic ideas are:
# [A1:B2:C3:D4:*:*] becomes a function: section_a1_b2_c3_d4____() {
# LIKE = OLD_MONITOR becomes a call: section_old_monitor
# And a section_call() function is implemented to use like:
#   section_call "unnamed"
#   section_call "default"
#   section_call "$mac"
#   section_call "$ip"
#   section_call "$hostname"
# Use lowercase in parameters.
# To name the functions something_* rather than section_*, use:
#   init2sh.awk -v prefix=something_

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
        "    # Prevent infinite recursion\n"\
        "    test -n \"$" section_id "\" && return\n"\
        "    " section_id "=defined"
}
{
if ($0 ~ /^[ ]*\[[^]]*\]/) {  # [Section]
    print "    unset " section_id "\n}\n"
    section=tolower($0)
    gsub("[][]", "", section)
    section_id=section
    section_id=prefix section_id
    gsub("[^a-z0-9]", "_", section_id)
    print section_id "() {\n"\
        "    test -n \"$" section_id "\" && return\n"\
        "    " section_id "=defined"
    # Append the appropriate case line
    list=list "\n        " section ")  " section_id " \"$@\" ;;"
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
    print "    unset " section_id "\n}\n\n"\
        "# Example usage: " prefix "call \"$IP\" or \"$MAC\" or \"$lower_hostname\"\n"\
        prefix "call() {\n"\
        "    local section\n"\
        "\n"\
        "    section=$1; shift\n"\
        "    case \"$section\" in\n"\
        "        unnamed)  " prefix "unnamed \"$@\" ;;"\
        list\
        "\n    esac\n"\
        "}"
}
