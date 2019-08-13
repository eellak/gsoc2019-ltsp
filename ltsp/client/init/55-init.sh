# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Override /sbin/init to run some LTSP code, then restore the real init

init_cmdline() {
    # Verify that this is a valid init environment
    test "$$" = "1" || die "ltsp init can run only as pid 1"
    re ensure_writable "$@"
    re mount_devices
    # Create the directory that indicates an "ltsp mode" boot
    re mkdir -p /run/ltsp/client
    # OK, ready to run all the main functions
    re run_main_functions "$_SCRIPTS" "$@"
    re exec /sbin/init
}

init_main() {
    local var

    # initrd-bottom may have renamed the real init
    if [ -f /sbin/init.real ]; then
        re rm /sbin/init
        re mv /sbin/init.real /sbin/init
    fi
    # Remember, `false && false` doesn't exit; use `||` when not using re/rw
    test -e "/etc/fstab" &&
        rw printf "# Empty fstab generated by LTSP.\n" > "/etc/fstab"
    # Use loglevel from /proc/cmdline instead of resetting it
    grep -qsw netconsole /proc/cmdline &&
        rw rm -f "/etc/sysctl.d/10-console-messages.conf"
    re patch_networking
    test -f "/usr/lib/tmpfiles.d/systemd.conf" &&
        rw sed "s|^[aA]|# &|" -i "/usr/lib/tmpfiles.d/systemd.conf"
    # Silence dmesg: Failed to open system journal: Operation not supported
    # Cap journal to 1M TODO make it configurable
    test -f "/etc/systemd/journald.conf" &&
        rw sed -e "s|[^[alpha]]*Storage=.*|Storage=volatile|" \
            -e "s|[^[alpha]]*RuntimeMaxUse=.*|RuntimeMaxUse=1M|" \
            -e "s|[^[alpha]]*ForwardToSyslog=.*|ForwardToSyslog=no|" \
            -i "/etc/systemd/journald.conf"
    test -f "/etc/systemd/system.conf" &&
        rw sed "s|[^[alpha]]*DefaultTimeoutStopSec=.*|DefaultTimeoutStopSec=10s|" \
            -i "/etc/systemd/system.conf"
    test -f "/etc/systemd/user.conf" &&
        rw sed "s|[^[alpha]]*DefaultTimeoutStopSec=.*|DefaultTimeoutStopSec=10s|" \
            -i "/etc/systemd/user.conf"
    # Mask services
    for var in apt-daily.service apt-daily-upgrade.service \
        snapd.seeded.service rsyslog.service
    do
        rw ln -s /dev/null "/etc/systemd/system/$var"
    done
    # TODO: or this; both are fast: rw systemctl mask --quiet --root=/ --no-reload apt-daily.service apt-daily-upgrade.service snapd.seeded.service rsyslog.service
    # Disable autologin on gdm3
    grep -qsw AutomaticLoginEnable /etc/gdm3/daemon.conf &&
        rw sed 's|^AutomaticLoginEnable\b.*=.*rue|AutomaticLoginEnable=False|' \
            -i /etc/gdm3/daemon.conf
    rw rm -f "/etc/init.d/shared-folders"
    rw rm -f "/etc/cron.daily/mlocate"
    rw rm -f "/var/crash/"*
    # TODO: proper DNS before systemd starts...
    rw rm -f "/etc/resolv.conf"
    for var in $DNS_SERVER; do
        rw echo "nameserver $var" >> "/etc/resolv.conf"
    done
    rw sed 's|^root:[^:]*:|root:$6$bKP3Tahd$a06Zq1j.0eKswsZwmM7Ga76tKNCnueSC.6UhpZ4AFbduHqWA8nA5V/8pLHYFC4SrWdyaDGCgHeApMRNb7mwTq0:|' -i "/etc/passwd"
    # TODO: pwmerge won't work with LANG=C or unset; maybe ensure a default
    # LANG=C.UTF-8 if it's unset for all scripts
    export LANG=${LANG:-C.UTF-8}
    re /usr/share/ltsp/client/login/pwmerge -lq /etc/ltsp /etc /etc
    rw sed "s|\bserver\b|replaced-server|g" -i /etc/hosts
    rw printf "$SERVER\tserver\n" >> /etc/hosts
    # TODO: remove: disable autologin
    rw rm -f /etc/lightdm/lightdm.conf
    rw setupcon
    if [ "$NFS_HOME" = "1" ]; then
        # mount.nfs means nfs-common installed
        # -o nolock bypasses the need for a portmap daemon
        # TODO: configurable home; also maybe put it in fstab...
        if is_command mount.nfs; then
            re mount -t nfs -o nolock "$SERVER:/srv/home" "/home"
        else
            re busybox mount -t nfs -o nolock "$SERVER:/srv/home" "/home"
        fi
    fi
    # Some live CDs don't have sshfs; allow the user to provide it
    if [ ! -x /usr/bin/sshfs ] && [ -x "/etc/ltsp/bin/sshfs-$(uname -m)" ]
    then
        rw ln -s "../../etc/ltsp/bin/sshfs-$(uname -m)" /usr/bin/sshfs
    fi
}

# TODO: this is initramfs-tools specific
patch_networking() {
    grep -Eqw 'root=/dev/nbd.*|root=/dev/nfs' /proc/cmdline ||
        return 0
    rw rm -rf /run/netplan /etc/netplan /lib/systemd/system-generators/netplan

    # prohibit network-manager from messing with the boot interface
    test -d /etc/NetworkManager/conf.d &&
        rw printf "%s" "[keyfile]
unmanaged-devices=interface-name:$DEVICE
" > /etc/NetworkManager/conf.d/ltsp.conf
    test -f /etc/network/interfaces &&
        rw printf "%s" "# Dynamically generated by LTSP.
$(test -d /etc/network/interfaces.d && echo '/etc/network/interfaces.d')

auto lo
iface lo inet loopback

auto $DEVICE
iface $DEVICE inet manual
" > /etc/network/interfaces
    # Never ifdown anything. Safer! :P
    test ! -x /sbin/ifdown ||
        rw ln -sf ../bin/true /sbin/ifdown
}

# If the root file system is read-only, create a tmpfs overlay over it.
# Tested over NBD and NFSv3, but it currently has issues over NFSv4:
# https://bugzilla.kernel.org/show_bug.cgi?id=199013
ensure_writable() {
    local mp

    test -w / && return 0
    # Sysadmins that want non-live mode should specify "rw" in the kernel
    # cmdline, so never do the following:
    # mount -o remount,rw / && return 0
    warn "The root file system isn't writable, activating overlay"
    # TODO: the following are currently untested
    # We want an existing mount point for the tmpfs outside of /run,
    # otherwise switch_root can't move the /run mount as it's in use.
    # Since ltsp must be installed for ro roots, let's use this dir:
    mp=/usr/share/ltsp/client/initrd-bottom
    test -d "$mp" || die "No mount point for overlay: $mp"
    re mount -t tmpfs tmpfs "$mp"
    re overlay "/" "$mp"
    re exec switch_root "$mp" "$0" "$@"
}

# Mount options from Debian initramfs-tools/init
mount_devices() {
    local mp mounts

    for mp in /dev /proc /run /sys; do
        test -d "$mp" || die "Missing directory: $mp"
    done
    test -f /proc/mounts ||
        re mount -vt proc -o nodev,noexec,nosuid proc /proc
    mounts=$(re awk '{ printf " %s ",$2 }' < /proc/mounts)
    test "$mounts" != "${mounts#* /sys }" ||
        re mount -vt sysfs -o nodev,noexec,nosuid sysfs /sys
    test "$mounts" != "${mounts#* /dev }" ||
        re mount -vt devtmpfs -o nosuid,mode=0755 udev /dev
    test "$mounts" != "${mounts#* /dev/pts }" ||
        re mount -vt devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts
    test "$mounts" != "${mounts#* /run }" ||
        re mount -vt tmpfs -o noexec,nosuid,size=10%,mode=0755 tmpfs /run
}
