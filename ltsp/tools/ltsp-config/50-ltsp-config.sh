#!/bin/sh

#  Copyright (c) 2012, Alkis Georgopoulos <alkisg@gmail.com>
#  Copyright (c) 2012, Vagrant Cascadian <vagrant@freegeek.org>

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

usage() {
    cat <<EOF
Usage: $0 TOOL [OPTION]

Generates or updates configuration files for certain parts of an LTSP server,
like lts.conf, the DHCP server, nbd-server etc.

Options:
  -d, --directory[=DIR]         A directory to search for configuration templates,
                                in addition to /usr/share/ltsp/examples.
  -h, --help                    Displays the ltsp-config help message.
  -l, --language[=LANG]         Preferred language for configuration files.
                                Support varies by distribution.
  -o, --overwrite               Overwrite existing configuration files.
      --version                 Output version information and exit.
  -q, --quiet                   Do not issue overwrite warnings

Tools:
  dnsmasq                       Configure dnsmasq.
      --enable-dns              Also enable DNS in dnsmasq, not just DHCP/TFTP.
      --no-proxy-dhcp           Don't enable proxyDHCP mode for detected subnets.
  isc-dhcp-server               Configure isc-dhcp-server.
  lts.conf                      Create a sample lts.conf.
  nbd-server                    Configure nbd-server.
  nfs                           Configure nfs exports.
EOF
}

# Replace a line matching a regex in a file with other line(s),
# or append them at the end of file if no match is found.
# Both $match and $replace must be valid sed expressions.
replace_line() {
    local match replace file
    match=$1
    replace=$2
    file=$3

    test -f "$file" || die "File not found: $file"

    if grep -q "$match" "$file"; then
        sed "s%$match%$replace%" -i "$file"
    else
        printf "$replace\n" >> "$file"
    fi
}

# Replace the "i386" in the example files with the default chroot name.
replace_arch() {
    local conf default
    conf=$1

    if [ -f "$conf" ]; then
        default=$(default_chroot)
        if [ "$default" != "i386" ]; then
            sed "s/i386/$default/" -i "$conf"
        fi
    else
        warn "File $conf not found."
    fi
}

# Check if a file exists and return error if --overwrite is not specified
check_overwrite() {
    if [ "$OVERWRITE" != "true" ] && [ -f "$1" ]; then
        if [ "$QUIET" != "true" ]; then
            warn "File $1 exists but --overwrite was not specified."
        fi
        return 1
    fi
    return 0
}

# Copy a file from /usr/share/ltsp/examples/$1 to $2,
# uncompressing it if necessary.
install_example() {
    local src dst dstdir language sname sext dir
    src=$1
    dst=$2

    if ! check_overwrite $dst; then
        die "Aborting"
    fi
    dstdir=${dst%/*}
    if [ ! -d "$dstdir" ]; then
        die "Directory $dstdir doesn't exist, maybe the tool you want to configure isn't installed?"
    fi

    # Prefer localized examples, if they exist.
    sname=${src%%.*}
    if [ "$sname" != "$src" ]; then
        sext=".${src#*.}"
    fi
    LANGUAGE=${LANGUAGE:-$LANG}
    for dir in "$DIRECTORY" /usr/share/ltsp/examples /usr/share/doc/ltsp-server/examples; do
        test -d "$dir" || continue
        for language in "${LANGUAGE%%:*}" "${LANGUAGE%%.*}" "${LANGUAGE%%_*}" ""; do
            language=${language:+"-$language"}
            if [ -f "$dir/$sname$language$sext" ]; then
                cp "$dir/$sname$language$sext" "$dst"
            elif [ -f "$dir/$sname$language$sext.gz" ]; then
                zcat "$dir/$sname$language$sext.gz" > "$dst"
            else
                continue
            fi
            replace_arch "$dst"
            echo "Created $dst"
            return 0
        done
    done
    die "Example file $src not found."
}

proxy_subnets() {
    local line subnet separator

    ip route show | while read line; do
        subnet=${line%%/*}
        case "$subnet" in
            127.0.0.1|169.254.0.0|192.168.67.0|*[!0-9.]*)
                # do nothing on these networks
                ;;
            *)
                # echo in dash translates "\n", use printf to keep it
                printf "%s" "${separator}dhcp-range=$subnet,proxy"
                # Insert a separator only after the first line
                separator="\n"
                ;;
        esac
    done
}

config_dnsmasq() {
    local conf

    conf="/etc/dnsmasq.d/ltsp-server-dnsmasq.conf"
    install_example "ltsp-server-dnsmasq.conf" "$conf"

    if [ "$NO_PROXY_DHCP" != "true" ]; then
        proxy_lines=$(proxy_subnets)
        if [ -n "$proxy_lines" ]; then
            replace_line "^#dhcp-range=.*,proxy" "$proxy_lines" "$conf"
        fi
    fi

    if [ "$ENABLE_DNS" = "true" ]; then
        sed 's/^port=0/#&/' -i "$conf"
        # If systemd-resolved is running, disable it
        if ss -ln sport eq 53 | grep -q 127.0.0.53; then
            mkdir -p /etc/systemd/resolved.conf.d
            cat >/etc/systemd/resolved.conf.d/ltsp.conf <<EOF
# Generated by \`ltsp-config dnsmasq --enable-dns\`.
[Resolve]
DNSStubListener=no
EOF
            echo "Disabled DNSStubListener in systemd-resolved"
            # The symlink may be relative or absolute, so better use grep
            if ls -l /etc/resolv.conf | grep -q /run/systemd/resolve/stub-resolv.conf; then
                ln -sf ../run/systemd/resolve/resolv.conf /etc/resolv.conf
                echo "Symlinked /etc/resolv.conf to ../run/systemd/resolve/resolv.conf"
            fi
            # Restart the one that won't be listening in :53 first
            systemctl restart systemd-resolved
        fi
        systemctl restart dnsmasq
    else
        systemctl restart dnsmasq
        if [ -f /etc/systemd/resolved.conf.d/ltsp.conf ]; then
            # We want to undo a previous --enable-dns
            rm -f /etc/systemd/resolved.conf.d/ltsp.conf
            echo "Reenabled DNSStubListener in systemd-resolved"
            if ls -l /etc/resolv.conf | grep -q /run/systemd/resolve/resolv.conf; then
                ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
                echo "Symlinked /etc/resolv.conf to ../run/systemd/resolve/stub-resolv.conf"
            fi
            systemctl restart systemd-resolved
        fi
    fi
}

config_isc_dhcp_server() {
    local conf

    conf="/etc/ltsp/dhcpd.conf"
    install_example "dhcpd.conf" "$conf"
    service isc-dhcp-server restart
}

config_lts_conf() {
    local default tftpdir

    default=$(default_chroot)
    for tftpdir in $TFTP_DIRS ; do
        if [ -d "$tftpdir/$TFTP_BOOT_DIR" ]; then
            mkdir -p "$tftpdir/$TFTP_BOOT_DIR/$default"
            install_example "lts.conf" "$tftpdir/$TFTP_BOOT_DIR/$default/lts.conf"
        fi
    done
}

config_nbd_server() {
    local restart_nbd name conf

    mkdir -p "/etc/nbd-server/conf.d"
    conf="/etc/nbd-server/conf.d/swap.conf"
    if check_overwrite "$conf"; then
        cat > "$conf" <<EOF
[swap]
exportname = /tmp/nbd-swap/%s
prerun = nbdswapd %s
postrun = rm -f %s
authfile = /etc/ltsp/nbd-server.allow
EOF
        echo "Created $conf"
        restart_nbd=true
    fi

    for name in $(list_chroots nbd); do
        conf="/etc/nbd-server/conf.d/ltsp_$name.conf"
        if check_overwrite "$conf"; then
            cat >"$conf" <<EOF
[$BASE/$name]
exportname = $BASE/images/$name.img
readonly = true
authfile = /etc/ltsp/nbd-server.allow
EOF
            echo "Created $conf"
            restart_nbd=true
        fi
    done

    if [ "$restart_nbd" = true ]; then
        # If nbd-server is already running, warn the user, else start it.
        if pgrep nbd-server >/dev/null; then
            warn "For nbd-server to re-read its configuration, you need to manually run:
    service nbd-server restart
THIS WILL DISCONNECT ALL RUNNING CLIENTS (they'll need to be rebooted)."
        elif ! { service nbd-server stop && service nbd-server start;}; then
            warn "Failed to start nbd-server."
        fi
    fi
}

config_nfs() {
    local nfs_exports nfs_line
    for cfg in /etc/exports /etc/exports.d/*.exports ; do
        if [ -f "${cfg}" ] && grep -q "^${BASE}" "${cfg}" ; then
            # Already configured, do nothing
            return 0
        fi
    done
    nfs_exports=/etc/exports
    nfs_line="${BASE} *(ro,no_root_squash,async,no_subtree_check)" 
    replace_line "^{BASE}.*" "${nfs_line}" "${nfs_exports}"
    service nfs-kernel-server restart
}

# distro specific functions

# Keeping this separate function to clearly show it can be distro specific. 
service() {
    /usr/sbin/service "$@"
}

# Set an optional MODULES_BASE, so help2man can be called from build env
MODULES_BASE=${MODULES_BASE:-/usr/share/ltsp}

# This also sources vendor functions and .conf file settings
. ${MODULES_BASE}/ltsp-server-functions

if ! args=$(getopt -n "$0" -o "d:hl:oq" \
    -l directory:,help,language:,overwrite,enable-dns,no-proxy-dhcp,version,quiet -- "$@")
then
    exit 1
fi
eval "set -- $args"
while true ; do
    case "$1" in
        -d|--directory) shift; DIRECTORY=$1 ;;
        -h|--help) usage; exit 0 ;;
        # If we ever localize ltsp-config, LANGUAGE will also be used in
        # the messages it displays, but we assume it's OK since the user
        # specified it.
        -l|--language) shift; LANGUAGE=$1 ;;
        -o|--overwrite) OVERWRITE=true ;;
        --version) ltsp_version; exit 0 ;;
        --enable-dns) ENABLE_DNS=true ;;
        --no-proxy-dhcp) NO_PROXY_DHCP=true ;;
        -q|--quiet) QUIET=true ;;
        --) shift ; break ;;
        *) die "$0: Internal error!" ;;
    esac
    shift
done

case "$1" in
    dnsmasq|isc-dhcp-server|lts.conf|nbd-server|nfs)
        config_function=$(echo "config_$1" | tr -c "[[:alpha:]\n]" "_")
        ;;
    *) die "$(usage)" ;;
esac
require_root

$config_function
