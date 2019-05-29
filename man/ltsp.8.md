## NAME
**ltsp** - entry point to Linux Terminal Server Project applets

## SYNOPSIS
**ltsp** [**-h**] [**-V**] [_applet_] [_applet\_options_]

## DESCRIPTION
Run the specified LTSP _applet_ with _applet\_options_. The following applets
are currently defined:

  **  config**: configure certain parts of the LTSP server
  **image**:  generate a squashfs image from a chroot directory or VM image
  **info**:   gather support information about the LTSP installation
  **initrd**: generate a squashfs image from a chroot directory or VM image
  **kernel**: copy the kernel from a VM image to the TFTP directory
  **swap**:   generate and export a swap file via NBD

To get help for each applet, use \`**ltsp-**_applet_ **--help**\` or
\`**man** **ltsp-**_applet_\`.

LTSP clients get the following applets instead; they should not be ran by
the user, but they do have man pages that describe that boot phase and the
relevant configuration parameters:

  **  init**:   after the initramfs; before /sbin/init
  **login**:  after login; before running the session; uid=user, not 0

For convenience, it's possible to use symlinks to ltsp.sh in order to run
applets, as long as the symlink name is **ltsp-**_applet_.

## OPTIONS
**-h**, **--help**
  Display a help message.

**-V**, **--version**
  Display the version information.

## FILES
**/etc/ltsp/ltsp.conf**: see **ltsp.conf**(5)

## ENVIRONMENT
All the long options can also be specified as environment variables in
UPPERCASE, for example:
```shell
PARTITION=1 ltsp kernel ...
```

## EXAMPLES
```shell
ltsp image -p 1 /srv/ltsp/x86_64/x86_64-flat.vmdk
```

## COPYRIGHT
Copyright 2019 the LTSP team, see AUTHORS

## SEE ALSO
**ltsp.conf**(5), **ltsp-config**(8), **ltsp-image**(8), **ltsp-info**(8),
**ltsp-initrd**(8), **ltsp-kernel**(8), **ltsp-swap**(8)
