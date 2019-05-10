#!/bin/sh
# This file is part of masd, https://masd.github.io
# Copyright 2018 the masd team, see AUTHORS.
# SPDX-License-Identifier: GPL-3.0-or-later

# Create uefi-boot.zip which contains necessary uefi boot files.
set -e

printf "Preparing files for UEFI boot:\n\n"

tmp=$(mktemp -d)
cp "${0%/*}/uefi-boot.cfg" "$tmp/grub.cfg"
cd "$tmp"

# Meh, shimx64.efi isn't available as a direct download. Get it from the .deb!
mkdir shim
shimdeb=$(wget -nv http://mirrors.edge.kernel.org/ubuntu/pool/main/s/shim/ -O - \
    | sed -n 's/.*\(shim.*amd64.deb\).*/\1/p' | sort -rV | head -n 1)
wget -nv "http://mirrors.edge.kernel.org/ubuntu/pool/main/s/shim/$shimdeb"
dpkg -x "$shimdeb" shim
mv shim/usr/lib/shim/shimx64.efi .
rm -rf shim
rm "$shimdeb"

# gcdx64 is designed for CDs and includes a memdisk with a grub.cfg that
# eventually loads $cmdpath/grub.cfg. This allows us to use the /EFI/Boot dir.
# But shimx64.efi hardcodes "grubx64.efi", so rename it.
wget -nv http://archive.ubuntu.com/ubuntu/dists/devel/main/uefi/grub2-amd64/current/gcdx64.efi.signed -O grubx64.efi

printf '\nUefi-boot successfully prepared folder %s with the following contents:\n' "$tmp"
ls -h
printf '
You can serve it to the local network by running:
cd %s
python -m SimpleHTTPServer
' "$tmp"
