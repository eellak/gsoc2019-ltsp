## NAME
**ltsp.conf** - main configuration file for LTSP

## SYNOPSIS
Any line beginning with a '#' is considered a comment. Options are of the format:

_VARIABLE_=_value_

Do not put spaces around the "=" sign, as ltsp.conf must be shell-sourceable. All _VARIABLES_ can also be defined in the command line while running `ltsp`, for example:
```shell
LTSP_BASE_DIR=/opt/ltsp ltsp kernel
```

## DESCRIPTION
LTSP by default is assuming that everything is under **/srv/ltsp**, but that can be configured by creating /etc/ltsp/ltsp.conf and defining one or more of the following variables:

* **LTSP_BASE_DIR=/srv/ltsp**: this is where the chroots or VMs are; so when you run `ltsp-update-image i386`, it will search for a directory named **/srv/ltsp/i386**; otherwise you'd need to provide the full path, for example `ltsp-update-image /home/username/VMs/buster`.
* **LTSP_NFS_DIR=/srv/ltsp**: this is used by `ltsp-config nfs`, to generate an appropriate /etc/exports, in `ltsp-config ipxe`, to create the appropriate kernel command lines for **nfsroot=**, and in `ltsp-config nbd`, to create appropriate [sections], for people still using NBD and trying to match ROOTPATH between NFS/NBD.
* **LTSP_IMAGE_DIR=/srv/ltsp/images**: this is where the squashfs files will be generated when running `ltsp-update-image`. The last word is also used in the kernel command line: **nfsroot=/srv/ltsp ltsp.loop=images/i386.img**.
* **LTSP_TFTP_DIR=/srv/ltsp**: used in `ltsp-config dnsmasq` and in `ltsp-update-kernels`. When running `ltsp-update-kernels i386`, the vmlinuz and initrd.img will go inside **$LTSP_TFTP_DIR/ltsp/i386**. The double "ltsp" directory there isn't pretty, and it even makes the kernel command lines longer (kernel /ltsp/i386/vmlinuz), but it's useful for those that use TFTP for other things too, so they don't use **/srv/ltsp** and do want all the ltsp-related stuff in a well organized TFTP subfolder. Hint: if you want to serve a chroot over NFS, and completely avoid `ltsp-update-kernels`, you can create a symlink from /srv/ltsp/ltsp/chroot to /srv/ltsp/chroot; this won't work on Ubuntu though as vmlinuz is 0600, not 0644.

TODO: we're already using subfolders in TFTP; is the "ltsp" subfolder really necessary? The ipxe/grub/memtest stuff and lts.conf can go in an ltsp subfolder then.<br>
ANSWER: yes, otherwise it's a lot less flexible, e.g. if we put LTSP_TFTP_DIR=/srv/ltsp, then ltsp-update-kernels overrides the chroot kernels as it's the same subdir; and if we put LTSP_TFTP_DIR=/srv/ltsp/tftp, then we can't use the "I'm exporting chroots over NFS, avoid ltsp-update-kernels" trick.

## COPYRIGHT
Copyright 2019 the LTSP team, see AUTHORS

## SEE ALSO
**ltsp-config**(8), **ltsp-image**(8), **ltsp-info**(8),
**ltsp-initrd**(8), **ltsp-kernel**(8), **ltsp-swap**(8)