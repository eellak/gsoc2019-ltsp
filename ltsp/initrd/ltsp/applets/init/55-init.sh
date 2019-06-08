# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Override /sbin/init to run some LTSP code, then restore the real init

init_cmdline() {
    local scripts

    scripts="$1"; shift
    warn "This is init-ltsp $*, type exit to continue booting"
    run_main_functions "$scripts" "$@"
    rm /sbin/init
    mv /sbin/init.real /sbin/init
    if ! mount | grep -qw dev; then
        echo ========NODEV========
        openvt -c 5 bash
    fi
    debug_shell
    exec /sbin/init
}

init_main() {
    local service

    rootmnt=/.
    test -e "$rootmnt/etc/fstab" &&
        printf "# Empty fstab generated by LTSP.\n" > "$rootmnt/etc/fstab"
    # Use loglevel from /proc/cmdline instead of resetting it
    if grep -qsw netconsole /proc/cmdline; then
        rw rm -f "$rootmnt/etc/sysctl.d/10-console-messages.conf"
    fi
    rm -rf /run/netplan /etc/netplan /lib/systemd/system-generators/netplan
    test -f "$rootmnt/usr/lib/tmpfiles.d/systemd.conf" &&
        rw sed "s|^[aA]|# &|" -i "$rootmnt/usr/lib/tmpfiles.d/systemd.conf"
    # Silence dmesg: Failed to open system journal: Operation not supported
    # Cap journal to 1M TODO make it configurable
    test -f "$rootmnt/etc/systemd/journald.conf" &&
        rw sed -e "s|[^[alpha]]*Storage=.*|Storage=volatile|" \
            -e "s|[^[alpha]]*RuntimeMaxUse=.*|RuntimeMaxUse=1M|" \
            -e "s|[^[alpha]]*ForwardToSyslog=.*|ForwardToSyslog=no|" \
            -i "$rootmnt/etc/systemd/journald.conf"
    test -f "$rootmnt/etc/systemd/system.conf" &&
        rw sed "s|[^[alpha]]*DefaultTimeoutStopSec=.*|DefaultTimeoutStopSec=10s|" \
            -i "$rootmnt/etc/systemd/system.conf"
    test -f "$rootmnt/etc/systemd/user.conf" &&
        rw sed "s|[^[alpha]]*DefaultTimeoutStopSec=.*|DefaultTimeoutStopSec=10s|" \
            -i "$rootmnt/etc/systemd/user.conf"
    for service in apt-daily.service apt-daily-upgrade.service snapd.seeded.service rsyslog.service; do
        rw ln -s /dev/null "$rootmnt/etc/systemd/system/$service"
    done
    rs rm -f "$rootmnt/etc/init.d/shared-folders"
    rw rm -f "$rootmnt/etc/cron.daily/mlocate"
    rw rm -f "$rootmnt/var/crash"*
    rw rm -f "$rootmnt/etc/resolv.conf"
    echo "nameserver 194.63.238.4" > "$rootmnt/etc/resolv.conf"
    /usr/lib/klibc/bin/nfsmount 10.161.254.11:/var/rw/home "$rootmnt/home"
    printf "qwer';lk\nqwer';lk\n" | rw chroot "$rootmnt" passwd
    re chroot "$rootmnt" useradd \
	    --comment 'LTSP live user,,,' \
	    --groups adm,cdrom,sudo,dip,plugdev,lpadmin  \
	    --create-home \
	    --password '$6$bKP3Tahd$a06Zq1j.0eKswsZwmM7Ga76tKNCnueSC.6UhpZ4AFbduHqWA8nA5V/8pLHYFC4SrWdyaDGCgHeApMRNb7mwTq0' \
	    --shell /bin/bash \
	    --uid 998 \
	    --user-group \
	    ltsp
}

# Get initramfs networking information into our own variables
import_netinfo() {
    local v script

    # Keep everything in space-separated lists
    if [ -z "$LTSP_MACS" ]; then
        while read -r iface mac <&3; do
            LTSP_MACS="$LTSP_MACS $mac"
        done 3<<EOF
$(ip -o link show |
    sed -n 's|[^ ]* *\([^:]*\).*link/ether *\([^ ]*\) .*|\1 \2|p')
EOF
        # Remove initial space
        LTSP_MACS=${LTSP_MACS# }
    fi

    if [ -z "$LTSP_IPS" ]; then
        while read -r ip <&3; do
            case "$ip" in
                127.0.0.1|::1) ;;
                *) LTSP_IPS="$LTSP_IPS $ip" ;;
            esac
        done 3<<EOF
$(ip -o address show |
    sed -n 's|[^ ]* [^ ]* *inet[^ ]* * \([^ /]*\).*|\1|p')
EOF
        LTSP_IPS=${LTSP_IPS# }
    fi

    if [ -z "$LTSP_SERVER" ] && [ -n "$LTSP_IPS" ]; then
        # Now we want to detect the LTSP server.
        # ROOTSERVER may be invalid in case of proxyDHCP.
        # `ps -fC nbd-client` doesn't work as it's just a kernel thread.
        # It may be available in /proc/cmdline, but it's complex to check
        # for all the variations of ip=, root=, netroot=, nbdroot= etc.
        # So if we have ONE TCP connection, assume it's the server.
        LTSP_SERVER=$(netstat -tun | sed -n 's|^tcp[^ ]* *[^ ]* *[^ ]* *[^ ]* *\([^ ]*\):[0-9]* .*|\1|p')
        if [ "$(expr match "$LTSP_SERVER" '[0-9a-f:.]*')" = "${#LTSP_SERVER}" ]; then
            # We need $LTSP_IFACE for network-manager blacklisting
            LTSP_IFACE=$(ip -o route get $LTSP_SERVER | sed -n 's|.* *dev *\([^ ]*\) .*|\1|p')
        else
            unset LTSP_SERVER
        fi
    fi
}

patch_networking() {
    # TODO: this is initramfs-tools specific
    grep -Eqw 'root=/dev/nbd.*|root=/dev/nfs' /proc/cmdline || return 0
    . /run/net-*.conf
    # prohibit network-manager from messing with the boot interface
    printf "%s" "[keyfile]
unmanaged-devices=interface-name:$DEVICE
" > "$rootmnt/etc/NetworkManager/conf.d/ltsp.conf"
    printf "%s" "# Dynamically generated by LTSP.
auto lo
iface lo inet loopback

auto $DEVICE
iface $DEVICE inet manual
" > "$rootmnt/etc/network/interfaces"
    # Never ifdown anything. Safer! :P
    ln -sf ../bin/true "$rootmnt/sbin/ifdown"
}

patch_root() {
    printf "# Empty fstab generated by LTSP.\n" > "$rootmnt/etc/fstab"
    if grep -qs 'AutomaticLoginEnable.*=' "$rootmnt/etc/gdm3/daemon.conf"; then
        sed -e 's/.*AutomaticLoginEnable[ ]*=.*/AutomaticLoginEnable = True/' \
            -e 's/.*AutomaticLogin[ ]*=.*/AutomaticLogin = administrator/' \
            -i "$rootmnt/etc/gdm3/daemon.conf"
    fi
    # return 0
    # Test automatic reboots, for stability!
    printf '#!/bin/sh
echo "This is RC LOCAL!" >&2
echo "This is RC LOCAL!"
# sleep 30  #  Cups does not like quick reboots and delays
# Systemd unit "Make remote CUPS printers available locally",
# sometimes needs 25 secs on NBD, 60 on NFS, with timeout=90
# reboot
' > "$rootmnt/etc/rc.local"
    chmod +x "$rootmnt/etc/rc.local"
}
