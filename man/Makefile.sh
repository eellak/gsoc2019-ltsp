#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Use go-md2man to convert the .md files into manpages;
# put the output in ./man/man[0-9] subdirectories, to make packaging easier,
# and to be able to test with: MANPATH=man man ltsp-kernel

VERSION=${1:-19.09}
date=$(date "+%Y-%m-%d")
for mp in *.[0-9].md; do
    applet_section=${mp%.md}
    applet=${applet_section%.[0-9]}
    section=${applet_section#$applet.}
    mkdir -p "man/man$section"
    {
        echo "$applet $section $date \"LTSP $VERSION\"
=====================================
"
        cat "$mp"
    } | go-md2man > "man/man$section/$applet.$section"
done
