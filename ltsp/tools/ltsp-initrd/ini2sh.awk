#!/usr/bin/awk -f
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Convert an .ini file, like lts.conf, to a shell sourceable file
# The basic ideas are:
# [A1:B2:C3:D4:*:*] becomes a function: section_a1_b2_c3_d4____() {
# LIKE = OLD_MONITOR becomes a call: section_old_monitor
# And finally the client calls only the default/mac/ip functions

BEGIN {
    # Cope with directives above the [Default] section, which is a user error
    section="section_unnamed"
    print section "() {"
    # Prevent infinite recursion
    print "test -n \"$" section "\" && return"
    print section "=defined"
}
{
if ($0 ~ /^[ ]*\[[^]]*\]/) {  # [Section]
    print "unset " section "\n}\n"
    section="section_" tolower($0)
    gsub("[][]", "", section)
    gsub("[^a-z0-9]", "_", section)
    print section "() {"
    # Prevent infinite recursion
    print "test -n \"$" section "\" && return"
    print section "=defined"
} else if (tolower($0) ~ /^like *=/) {  # LIKE = xxx
    value=tolower($0)
    sub("like *= *", "", value)
    print "section_" value
} else if ($0 ~ /^[a-zA-Z0-9_]* *=/) {  # VAR = xxx
    value=$0
    sub(" *= *", "=", value)  # remove spaces only around the first =
    print value
} else {
    print $0
}
}
END {
    print "unset " section "\n}"
}
