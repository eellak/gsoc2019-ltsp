#!/bin/sh

#  Copyright (c) 2006-2009 Vagrant Cascadian <vagrant@freegeek.org>
#  2012, Alkis Georgopoulos <alkisg@gmail.com>

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, you can find it on the World Wide
#  Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
#  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
#  MA 02110-1301, USA.

# generic functions
usage() {
    cat <<EOF
Usage: $0 [OPTION]

Displays information useful to troubleshooting issues on an LTSP
server. Information should include server distro and release,
versions of LTSP related packages installed on the server, LTSP
chroots and their package versions, LTSP image files and lts.conf(5).

Options:
  -h, --help                    Displays the ltsp-info help message.
  -n, --no-server-info          Do not display server information.
  -v, --verbose                 Display more information, such as including the contents
                                of detected files.
      --version                 Output version information and exit.
EOF
}

find_chroots() {
    find -L "$BASE/" -mindepth 1 -maxdepth 1 -type d ! -name images
}

find_lts_conf() {
    chroot=$1
    chroot_name=$(basename $chroot)
    lts_conf_dirs="$chroot/etc /var/lib/tftpboot/ltsp/$chroot_name /srv/tftp/ltsp/$chroot_name /tftpboot/ltsp/$chroot_name"
    for lts_conf_dir in $lts_conf_dirs ; do
        lts_conf=$lts_conf_dir/lts.conf
        if [ -f "$lts_conf" ]; then
            echo found: "$lts_conf"
            if [ "$verbose" = "true" ]; then
                cat "$lts_conf"
            fi
            echo
        fi
    done
}

find_images() {
    if [ -d "$BASE/images" ]; then
        for image in $(find -L "$BASE/images/" -type f -name '*.img'); do
            echo found image: $image
            if [ "$verbose" = "true" ] && [ -x /usr/bin/file ]; then
                file $image 
            fi
            echo
        done
    fi     
}

# Distros may override that if they don't support lsb_release
server_info() {
    echo server information:
    lsb_release --all
    echo
}


# distro specific functions
server_packages() {
    die "Your distro needs to implement function server_packages in order to support $0."
}

chroot_packages() {
    die "Your distro needs to implement function chroot_packages in order to support $0."
}

chroot_release() {
    die "Your distro needs to implement function chroot_release in order to support $0."
}

# Set an optional MODULES_BASE, so help2man can be called from build env
MODULES_BASE=${MODULES_BASE:-/usr/share/ltsp}

# This also sources vendor functions and .conf file settings
. ${MODULES_BASE}/ltsp-server-functions

export BASE=${BASE:-/opt/ltsp}                # LTSP base directory

for opt in $@ ; do
    case $opt in
        --help|-h) usage; exit 0 ;;
        --no-server-info|-n) server_info="false" ;;
        --verbose|-v) verbose="true" ;;
        --version) ltsp_version; exit 0 ;;
    esac
done

if [ "$server_info" != "false" ]; then
    server_info
    server_packages
fi
for chroot in $(find_chroots) ; do
    chroot_name=$(basename $chroot)
    if [ "$verbose" = "true" ]; then
        chroot_release
    fi
    chroot_packages $chroot
    find_lts_conf $chroot
done
find_images
