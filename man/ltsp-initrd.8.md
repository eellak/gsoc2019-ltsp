## NAME
**ltsp initrd** - create the ltsp.img initrd add-on

## SYNOPSIS
**ltsp** [_ltsp-options_] **initrd**

## DESCRIPTION
Create a secondary initrd in /srv/tftp/ltsp/ltsp.img, that contains the LTSP
client code from /usr/share/ltsp/{client,common} and the client settings file
from /etc/ltsp/client.conf. LTSP clients receive this initrd in addition to
their normal one.

This means that whenever you edit **client.conf**, you need to run
`ltsp initrd` to update **ltsp.img**, and reboot the clients.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.
