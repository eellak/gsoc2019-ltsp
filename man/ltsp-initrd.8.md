## NAME
**ltsp initrd** - create the ltsp.img initrd add-on

## SYNOPSIS
**ltsp initrd** [**-h**] [**-V**]

## DESCRIPTION
Create a secondary initrd, $TFTP_DIR/ltsp/ltsp.img, that contains the
ltsp client code from /usr/share/ltsp/initrd/* and the client settings file
from /etc/ltsp/client.conf. LTSP clients receive this initrd in addition to
their normal one.

This means that whenever you edit **client.conf**, you need to run
`ltsp initrd` to update **ltsp.img**, and reboot the clients.


## OPTIONS
**-h**, **--help**
  Display a help message.

**--version**
  Display the version information.
