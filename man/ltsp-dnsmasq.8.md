## NAME
**ltsp dnsmasq** - configure dnsmasq for LTSP

## SYNOPSIS
**ltsp [_ltsp-options_] dnsmasq** [**-d=**_0|1_] [**-h**] [**-p=**_0|1_] [**-r=**_0|1_] [**-s=**_"dns servers"_] [**-t=**_0|1_] [-V]

## DESCRIPTION
Install /etc/dnsmasq.d/ltsp-dnsmasq.conf, while adjusting the template with
the provided parameters.
System administrators may override template configuration files in /etc/ltsp/.

## OPTIONS
**-d**, **--dns=**_0|1_
  Enable or disable the DNS service. Defaults to 0.
Enabling the DNS service of dnsmasq allows caching of client requests,
custom DNS results, blacklisting etc, and automatically disables
DNSStubListener in systemd-resolved on the LTSP server.

**-h**, **--help**
  Display a help message.

**-p**, **--proxy-dhcp=**_0|1_
  Enable or disable the proxy DHCP service. Defaults to 1.
Proxy DHCP means that the LTSP server sends the boot filename, but it leaves
the IP leasing to an external DHCP server, for example a router or pfsense
or a Windows DHCP server. It's the easiest way to set up LTSP, as it only
requires a single NIC with no static IP, no need to rewire switches etc.

**-r**, **--real-dhcp=**_0|1_
  Enable or disable the real DHCP service. Defaults to 1.
In dual NIC setups, you only need to configure the internal NIC to a static
IP of 192.168.67.1; LTSP will try to autodetect everything else.
The real DHCP service doesn't take effect in single NIC setups so there's no
need to disable it unless you want to run isc-dhcp-server on the LTSP server.

**-s**, **--dns-servers=**_"space separated list"_
  Set the DNS servers DHCP option. Defaults to autodetection.
Proxy DHCP clients don't receive DHCP options, so it's recommended to use the
client.conf DNS_SERVERS directive when autodetection isn't appropriate.

**-t**, **--tftp=**_0|1_
  Enable or disable the TFTP service. Defaults to 1.

**-V**, **--version**
  Display the version information.

## FILES
**/etc/dnsmasq.d/ltsp.conf**
  All the long options can also be specified as UPPER_CASE variables in
ltsp.conf, for example:
```shell
TFTP_DIR=/srv/tftp
PROXY_DHCP=0
```

## ENVIRONMENT
All the long options can also be specified as UPPER_CASE environment
variables, for example:
```shell
DNS_SERVERS="192.168.1.1 8.8.8.8" ltsp dnsmasq
```

## EXAMPLES
Create a default dnsmasq configuration, overwritting the old one:
```shell
ltsp --overwrite dnsmasq
```
A dual NIC setup with the DNS service enabled:
```shell
ltsp -o dnsmasq -d=1 -p=0 -s="0.0.0.0 8.8.8.8 208.67.222.222"
```
