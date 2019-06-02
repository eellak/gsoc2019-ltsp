## NAME
**ltsp** - entry point to Linux Terminal Server Project applets

## SYNOPSIS
**ltsp** [**-b=**_base-dir_] [**-h**] [**-i=**_image-dir_]  [**-n=**_nfs-dir_] [**-o**] [**-t=**_tftp-dir_] [**-V**] [_applet_] [_applet-options_]

## DESCRIPTION
Run the specified LTSP _applet_ with _applet-options_. To get help with applets and their options, run \`**man** **ltsp** _applet_\` or \`**ltsp** _applet_ **--help**\`.

## APPLETS
The following applets are currently defined:

  **  chroot**: chroot into an LTSP root directory or image, for maintenance
  **config**: configure certain parts of the LTSP server (client.conf, dnsmasq, ipxe, isc-dhcp, nbd, nfs)
  **image**:  generate a squashfs image from a chroot directory or VM image
  **info**:   gather support information about the LTSP installation
  **initrd**: create the ltsp.img initrd add-on
  **kernel**: copy the kernel and initrd from a VM image to the TFTP directory
  **swap**:   generate and export a swapfile via NBD

LTSP clients get the following applets instead; they should not be run by the user, but they do have man pages that describe that boot phase and the relevant configuration parameters:

  **  init**:   after the initramfs; before /sbin/init; configures everything
  **local**:  cache the ltsp image to a local disk
              configure grub (pc/uefi), ipxe, local home...
              manually invoked by the user!
  **pre-login**: right before login; sync user accounts, do server load balancing etc
  **post-login**:  right after login; before running the session; uid=user, not 0

Developers of other packages may use symlinks to ltsp.sh in order to run applets, as long as the symlink name is **ltsp-**_applet_.

## OPTIONS
LTSP by default places everything under _/srv/ltsp_, but that can be configured by passing one or more of the following parameters:

**-b**, **--base-dir=**_/srv/ltsp_
  This is where the chroots or VMs are; so when you run `ltsp image x86_64`, it will search for a directory named **/srv/ltsp/x86_64**; otherwise you'd need to provide the full path, for example `ltsp image /home/username/VMs/x86_64`.

**-h**, **--help**
  Display a help message.

**-i**, **--image-dir=**_/srv/ltsp/images_
  This is where the squashfs files will be generated when running `ltsp image`. The rightmost directory is also used in the kernel command line: **nfsroot=/srv/ltsp ltsp.loop=images/x86_64.img**.

**-n**, **--nfs-dir=**_/srv/ltsp_
  This is used by `ltsp config nfs`, to generate an appropriate /etc/exports, in `ltsp config ipxe`, to create the appropriate kernel command lines for **nfsroot=**, and in `ltsp config nbd`, to create appropriate [sections], for people still using NBD and trying to match ROOTPATH between NFS/NBD.

**-o**, **--overwrite**
  Overwrite all existing files. Usually applets refuse to overwrite configuration files that may have been modified by the user, like boot.ipxe.

**-t**, **--tftp-dir=**_/srv/ltsp_
  Used in `ltsp config dnsmasq` and in `ltsp kernel`. When running `ltsp kernel x86_64`, the vmlinuz and initrd.img will go inside **$TFTP_DIR/ltsp/x86_64**. The double "ltsp" directory there isn't pretty, and it even makes the kernel command lines longer (kernel /ltsp/x86_64/vmlinuz), but it's useful for those that use TFTP for other things too, so they don't use **/srv/ltsp** and do want all the ltsp-related stuff in a well organized TFTP subfolder. Hint: if you want to serve a chroot over NFS, and completely avoid `ltsp kernels`, you can create a symlink from /srv/ltsp/ltsp/chroot to /srv/ltsp/chroot; this won't work on Ubuntu though as vmlinuz is 0600, not 0644.

TODO: we're already using subfolders in TFTP; is the "ltsp" subfolder really necessary? The ipxe/grub/memtest stuff and lts.conf can go in an ltsp subfolder then.

ANSWER: yes, otherwise it's a lot less flexible, e.g. if we put TFTP_DIR=/srv/ltsp, then ltsp kernel overrides the chroot kernel as it's the same subdir; and if we put TFTP_DIR=/srv/ltsp/tftp, then we can't use the "I'm exporting chroots over NFS, avoid ltsp kernel" trick.

**-V**, **--version**
  Display the version information.

## FILES
**/etc/ltsp/ltsp.conf**
  All the long options can also be specified as variables in the **ltsp.conf** configuration file in UPPERCASE, using underscores instead of hyphens.

## ENVIRONMENT
All the long options can also be specified as environment variables in UPPERCASE, for example:
```shell
BASE_DIR=/opt/ltsp PARTITION=1 ltsp kernel ...
```

## EXAMPLES
```shell
ltsp image -p 1 /srv/ltsp/x86_64/x86_64-flat.vmdk
```
