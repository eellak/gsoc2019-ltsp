## NAME
**ltsp.conf** - client configuration file for LTSP

## SYNOPSIS
The LTSP client configuration file is placed at `/etc/ltsp/ltsp.conf`
and it losely follows the .ini format. It is able to control various
settings of the LTSP server and clients. After every ltsp.conf modification,
the `ltsp initrd` command needs to be run so that it's included in the
additional ltsp.img initrd that is sent when the clients boot.

## CREATION
Non-experienced sysadmins may use the following commands to create an
ltsp.conf file; except for the sudo command, run the rest from your own
account, not as root; this will allow you to edit ltsp.conf with a
visual editor (e.g. gedit) without requiring the use of sudo.

```shell
( umask 0077; echo [default] > /tmp/ltsp.conf )
sudo mv /tmp/ltsp.conf /etc/ltsp/
xdg-open /etc/ltsp/ltsp.conf
```

## SYNTAX
An example is worth a thousand words:

```shell
# /bin/sh -n
# Example /etc/ltsp/ltsp.conf configuration file
# Documentation: man:ltsp.conf(5)

# The default section applies to all ltsp clients
[default]
# Use NFS3 home. Faster but insecure!
FSTAB_NFS="server:/home /home nfs 0 0"

# The ltsp client at the library
[61:6c:6b:69:73:67]
HOSTNAME=pc01
LIKE=CRT_MONITOR

# Include this section to clients with CRT screens
[CRT_MONITOR]
X_MODE_0="1024x768x32@85"
```

The configuration file is separated into sections. The [default] section
applies to all clients, including the server (e.g. for setting BASE_DIR).
Sections with a lowercase MAC address, an IP or a hostname can be used
to apply parameters to selected clients. Globs are also allowed, for
example [192.168.*].

It's also possible to group parameters into named sections like [CRT_MONITOR]
in the example, and reference them from other sections with the LIKE=
parameter.

The ltsp.conf configuration file is internally transformed into a shell
script, so all the shell syntax rules apply, except for the sections headers
which are transformed into functions.

This means that you must not use spaces around the "=" sign,
and that you may write comments using the "#" character.

The `ltsp initrd` command does a quick syntax check by running

```shell
sh -n /etc/ltsp/ltsp.conf
```

and aborts if it detects syntax errors.

## PARAMETERS
The following parameters are currently defined; an example is given in
each case.

**DNS_SERVER=**_8.8.8.8 208.67.222.222_
: Specify the DNS servers for the clients.

**FSTAB_x=**_"server:/home /home nfs 0 0"_
: All parameters that start with FSTAB_ are sorted and then their values
are written to /etc/fstab at the client init phase.

**HOSTNAME=**_"pc01"_
: Specify the client hostname.

**HOSTS_x=**_"192.168.67.10 nfs-server"_
: All parameters that start with HOSTS_ are sorted and then their values
are written to /etc/hosts at the client init phase.

**POST_APPLET_x=**_"ln -s /etc/ltsp/xorg.conf /etc/X11/xorg.conf"_
: All parameters that start with POST_ and then have an ltsp client applet
name are sorted and their values are executed after the main function of
that applet. See the ltsp(8) man page for the available applets, for
example POST_INITRD_BOTTOM_x, POST_LOGIN_x etc. The usual place to run
client initialization commands that don't need to daemonize is
POST_INIT_x.

**PRE_APPLET_x=**_"debug_shell"_
: All parameters that start with PRE_ and then have an ltsp client applet
name are sorted and their values are executed before the main function of
that applet.

## EXAMPLES
A long example was give above in the SYNTAX section. Note that the
"# /bin/sh -n" fake shebang was used to easily enable shell highlighting
in gedit/pluma.

If some clients need an custom xorg.conf file, create it in e.g.
`/etc/ltsp/xorg-nvidia.conf`, and put the following in ltsp.conf
to dynamically symlink it for those clients on boot:

```shell
[pc01]
LIKE=NVIDIA_CLIENTS

[NVIDIA_CLIENTS]
POST_INIT_LN_XORG="ln -sf ../ltsp/xorg-nvidia.conf /etc/X11/xorg.conf"
```

Since ltsp.conf is transformed into a shell script and sections into
functions, it's possible to do all kinds of fancy things, even to directly
include code. But it's usually best to keep it simple and put code in
separate scripts.

```shell
[default]
# Set the root password to "qwer1234" for all clients.
# The password hash contains ' and $, making it hard to escape it,
# so use a "HEREDOC" instead.
{ POST_INIT_SET_ROOT_HASH=$(cat); } <<"EOF"
sed 's|^root:[^:]*:|root:$6$p2LdWE6j$PDd1TUzGvvIkj9SE8wbw1gA/MD66tHHlStqi1.qyv860oK47UnKcafSKqGp7cbgZUPlgyPv6giCVyCSCdJt1b0:|' -i /etc/shadow
EOF

[initrd_bottom/default]
# Putting commands under [applet/default] sections means that they will
# only be run in that specific boot phase, not by all ltsp client applets.
# The following commands work around LP: #345374 bug for sis clients.
test -d /sys/module/sis190 || return 0
ip link set dev "$DEVICE" mtu 1492
```
