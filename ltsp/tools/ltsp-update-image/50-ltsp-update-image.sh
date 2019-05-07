#!/bin/sh
#
#  Copyright (c) 2007 Canonical LTD
#
#  Author: Oliver Grawert <ogra@canonical.com>
#
#  2007, Scott Balneaves <sbalneav@ltsp.org>
#        Warren Togami <wtogami@redhat.com>
#  2008, Vagrant Cascadian <vagrant@freegeek.org>
#  2010, Gideon Romm <gadi@ltsp.org>
#  2012, Alkis Georgopoulos <alkisg@gmail.com>
#
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
#

usage() {
    cat <<EOF
Usage: $0 [OPTION] [CHROOT...]

Generates a compressed squashfs NBD image from an LTSP chroot and exports
it with nbd-server. Chroot can be a full path or a subdirectory of the LTSP
base directory, and it defaults to the host architecture if unset.

Options:
  -b, --base[=PATH]         The LTSP base directory Defaults to /opt/ltsp if unspecified.
  -c, --cleanup             Temporarily remove user accounts, logs, caches etc from
                            the chroot before exporting the image. The chroot arch
                            is required to be compatible with the server arch.
      --compression[=TYPE]  Compress the resulting image with TYPE
                            (gzip, lzo, xz, lz4). If unspecified, use
                            mksquashfs default.
  -e, --exclude[=LIST]      List of dirs/files to exclude from the image.
                            This is in addition to /etc/ltsp/ltsp-update-image.excludes.
  -f, --config-nbd          Generate appropriate nbd-server configuration files.
                            It's automatically set if NFS isn't used or if other LTSP
                            generated nbd-server configuration files already exist.
  -h, --help                Displays the ltsp-update-image help message.
  -m, --no-compress         Don't compress the generated image.
  -n, --no-backup           Don't backup chroot.img to chroot.img.old.
  -r, --revert              Swap chroot.img with chroot.img.old and update kernels.
      --version             Output version information and exit.
EOF
}

trap_cleanup() {
    # Don't stop on errors within this function.
    # Save and restore flags in a way that works with dash and bash.
    local orig_flags
    orig_flags=$(set +o)
    set +e

    # Stop trapping
    trap - 0 HUP INT QUIT KILL SEGV PIPE TERM
    umount_marked
    rmdir "$cowbase"
    unlock_package_management
    eval "$orig_flags"
}

# Get a sorted list of all "real" mount points under $chroot,
# with $chroot included, even if it's not a mount point.
get_mounts() {
    local chroot mounts src system point type rest excluded found_chroot
    chroot=$1

    # Provide an environment variable to exclude some submounts
    excluded=",${EXCLUDED_MOUNTS},"
    echo "$chroot"
    while read system point type rest; do
        case "$excluded" in
            ,$point,) continue ;;
        esac
        # Avoid CDs, USB sticks, virtual file systems etc.
        case "$type" in
            btrfs|ext*) true ;;
            *) continue ;;
        esac
        case "$point/" in
            $chroot/|/dev/*|/proc/*|/run/*|/sys/*|/tmp/*) continue ;;
            ${chroot%/}/*) echo "$point" ;;
        esac
    done < /proc/mounts | sort -u
}

# Create a COW view of the chroot and run ltsp-cleanup in it.
run_cleanup() {
    # Global variables defined here: cowbase, cowroot
    local chroot modules module cowtmp submount
    chroot=$1

    if [ ! -x "$chroot/usr/share/ltsp/ltsp-cleanup" ]; then
        die "Script $chroot/usr/share/ltsp/ltsp-cleanup does not exist, cannot cleanup the chroot."
    fi
    # To be less intrusive, we prefer modules that are already loaded.
    # If none is, then we try to load them in the following order.
    # overlay was called overlayfs in Ubuntu before it got upstreamed,
    # and it used a different mounting syntax.
    modules=""
    for module in overlay overlayfs aufs; do
        if [ -d "/sys/module/$module" ]; then
            modules="$module $modules"
        else
            modules="$modules $module"
        fi
    done
    for module in $modules; do
        modprobe -q "$module" || true
        # In e.g. Ubuntu 15.10, `modprobe overlayfs` succeeds for compatibility,
        # but overlay is loaded instead, and it's using the new syntax.
        test -d "/sys/module/$module" && break
    done
    test -d "/sys/module/$module" || die "No overlay or aufs support detected"

    lock_package_management
    cowbase=$(mktemp -d)
    trap "trap_cleanup" 0 HUP INT QUIT KILL SEGV PIPE TERM
    # Overlayfs misbehaves when $cowroot is in the same file system as
    # $chroot, so we use a tmpfs. It's also easier to clean it up afterwards.
    mark_mount -t tmpfs -o mode=0700 tmpfs "$cowbase"
    cowroot=$cowbase/root
    mkdir "$cowroot"
    cowtmp=$cowbase/tmp
    mkdir "$cowtmp"

    # We also want to mount whatever submounts the chroot has, e.g. /boot.
    # Here's what a `mount` command output will look like afterwards:
    # tmpfs on /tmp/tmp.EYFLkg6dYu type tmpfs (rw,relatime,mode=755)
    # overlay on /tmp/tmp.EYFLkg6dYu/chroot type overlay (rw,relatime,lowerdir=/,upperdir=/tmp/tmp.EYFLkg6dYu/tmp/.up,workdir=/tmp/tmp.EYFLkg6dYu/tmp/.work)
    # overlay on /tmp/tmp.EYFLkg6dYu/chroot/boot type overlay (rw,relatime,lowerdir=/boot,upperdir=/tmp/tmp.EYFLkg6dYu/tmp/boot/.up,workdir=/tmp/tmp.EYFLkg6dYu/tmp/boot/.work)
    while IFS= read -r submount; do
        case "$module" in
            overlay)
                mkdir -p "$cowtmp${submount%/}/.work"
                mkdir -p "$cowtmp${submount%/}/.upper"
                mark_mount -t overlay -o "lowerdir=$submount,upperdir=$cowtmp${submount%/}/.upper,workdir=$cowtmp${submount%/}/.work" overlay "$cowroot${submount%/}"
                ;;
            overlayfs)
                mkdir -p "$cowtmp${submount%/}/.upper"
                mark_mount -t overlayfs -o "lowerdir=$submount,upperdir=$cowtmp${submount%/}/.upper" overlayfs "$cowroot${submount%/}"
                ;;
            aufs)
                mkdir -p $cowtmp${submount%/}
                mark_mount -t aufs -o "dirs=$cowtmp${submount%/}=rw:$submount=ro" aufs "$cowroot${submount%/}"
                ;;
            esac
    done <<EOF
$(get_mounts "$chroot")
EOF
    chroot "$cowroot" /usr/share/ltsp/ltsp-cleanup --yes
}

generate_image() {
    local chroot name imgdir nice ionice
    chroot=$1

    # If the chroot is a subdir of $BASE, make it an absolute path
    if [ "$chroot" != "/" ]; then
        chroot=${chroot%/}
        test -d "$BASE/$chroot" && chroot="$BASE/$chroot"
    fi
    test -d "$chroot" || die "Chroot $chroot does not exist."
    name=${chroot##*/}
    name=${name%.*}
    # If the chroot has no name part, e.g. /, name it after the host arch
    name=${name:-$(detect_arch)}
    imgdir=$BASE/images
    mkdir -p "$imgdir"

    if [ "$REVERT" = true ]; then
        test -f "$imgdir/$name.img.old" ||
            die "$imgdir/$name.img.old is missing, cannot revert to it"
        if [ -f "$imgdir/$name.img" ]; then
            # Swap old with new file
            mv "$imgdir/$name.img" "$imgdir/$name.img.tmp"
            mv "$imgdir/$name.img.old" "$imgdir/$name.img"
            mv "$imgdir/$name.img.tmp" "$imgdir/$name.img.old"
        else
            mv "$imgdir/$name.img.old" "$imgdir/$name.img"
        fi
        echo "Reverted to $imgdir/$name.img.old, please reboot your clients."
    else
        if [ "$CLEANUP" = true ]; then
            # run_cleanup sets cowroot=$(mktemp -d)/root for mksquashfs
            run_cleanup "$chroot"
        else
            cowroot=$chroot
        fi

        test -f /etc/ltsp/ltsp-update-image.excludes && EXCLUDE_FILE="/etc/ltsp/ltsp-update-image.excludes"
        test -x /usr/bin/nice && nice=nice || unset nice
        test -x /usr/bin/ionice && /usr/bin/ionice -c3 true 2>/dev/null && ionice=ionice || unset ionice
        if ! $nice $ionice mksquashfs "$cowroot" "$imgdir/$name.img.tmp" \
            -no-recovery -noappend -wildcards ${EXCLUDE_FILE:+-ef "$EXCLUDE_FILE"} \
            ${EXCLUDE:+-e "$EXCLUDE"} ${NO_COMPRESS:+-noF -noD -noI -no-exports} \
            ${COMPRESSION:+-comp $COMPRESSION}
        then
            rm -f "$imgdir/$name.img.tmp"
            die "mksquashfs failed to build the LTSP image, exiting"
        fi
        if [ -f "$imgdir/$name.img" ] && [ "$NO_BACKUP" != true ]; then
            mv "$imgdir/$name.img" "$imgdir/$name.img.old"
        fi
        mv "$imgdir/$name.img.tmp" "$imgdir/$name.img"
    fi

    PREFER_NBD_IMAGE="$REVERT" ltsp-update-kernels ${BASE:+-b "$BASE"} "$name"

    if [ "$cowroot" != "$chroot" ] && [ "$REVERT" != true ]; then
        trap_cleanup
    fi
}


# Distro specific functions

lock_package_management() {
    warn "Your distro doesn't support package management locking, continuing without locking..."
}

unlock_package_management() {
    if [ -n "$lockpid" ]; then
        kill "$lockpid" || true
        unset lockpid
    fi
}

# Set an optional MODULES_BASE, so help2man can be called from build env
MODULES_BASE=${MODULES_BASE:-/usr/share/ltsp}

# This also sources vendor functions and .conf file settings
. ${MODULES_BASE}/ltsp-server-functions

if ! args=$(getopt -n "$0" -o "b:ce:fhmnr" \
    -l "base:,cleanup,exclude:,compression:,config-nbd,help,no-compress,no-backup,revert,version" -- "$@")
then
    exit 1
fi
eval "set -- $args"
while true ; do
    case "$1" in
        -b|--base) shift; BASE=$1 ;;
        -c|--cleanup) CLEANUP=true ;;
        --compression) shift; COMPRESSION="$1" ;;
        -e|--exclude) shift; EXCLUDE=$1 ;;
        -f|--config-nbd) CONFIG_NBD=true ;;
        -h|--help) usage; exit 0 ;;
        -m|--no-compress) NO_COMPRESS=true ;;
        -n|--no-backup) NO_BACKUP=true ;;
        -r|--revert) REVERT=true ;;
        --version) ltsp_version; exit 0 ;;
        --) shift ; break ;;
        *) die "$0: Internal error!" ;;
    esac
    shift
done
require_root

BASE=${BASE:-/opt/ltsp}
# Remove trailing /, if present
BASE=${BASE%/}
if [ -z "$CONFIG_NBD" ]; then
    if [ -d /etc/nbd-server/conf.d ] &&
        [ -n "$(find /etc/nbd-server/conf.d/ -type f -name 'ltsp_*.conf' ! -name ltsp_swap.conf)" ]
    then
        CONFIG_NBD=true
    fi
    if [ -z "$CONFIG_NBD" ]; then
        if grep -qsr ^/opt/ltsp /etc/exports /etc/exports.d/; then
            die "Your system seems to be using NFS to serve LTSP chroots.
If you're absolutely certain you want to switch to NBD, run:
    $0 --config-nbd $*"
        fi
    fi
fi

# Chroots can be specified in the command line. If not, update all of them.
if [ $# -eq 0 ]; then
    set -- $(list_chroots nfs)
fi
test $# -gt 0 || die "No chroots found in $BASE"

for chroot in "$@"; do
    generate_image "$chroot"
done

ltsp-config --quiet nbd-server
