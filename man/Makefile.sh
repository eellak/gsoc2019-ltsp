#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Use go-md2man to convert the .md files into manpages;
# put the output in ./man/man[0-9] subdirectories, to make packaging easier,
# and to be able to test with: `MANPATH=man man ltsp kernel`

VERSION=$(. ../ltsp/common/ltsp/55-ltsp.sh && echo "$_VERSION")
date=$(date "+%Y-%m-%d")
rm -rf ../man/man
for mp in *.[0-9].md; do
    applet_section=${mp%.md}
    applet=${applet_section%.[0-9]}
    section=${applet_section#$applet.}
    mkdir -p "man/man$section"
    # TODO: omit the current applet from SEE ALSO
    go-md2man > "man/man$section/$applet.$section" <<EOF
$applet $section $date "LTSP $VERSION"
=====================================
$(cat "$mp")
## COPYRIGHT
Copyright 2019 the LTSP team, see AUTHORS

## SEE ALSO
**ltsp(8)**, **ltsp chroot**(8), **ltsp client.conf**(5), **ltsp dnsmasq**(8),
**ltsp image**(8), **ltsp info**(8), **ltsp initrd**(8), **ltsp ipxe**(8),
**ltsp isc-dhcp**(8), **ltsp kernel**(8), **ltsp nbd**(8),
**ltsp nfs**(8), **ltsp swap**(8)
EOF
done
