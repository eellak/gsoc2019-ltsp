## NAME
**ltsp-kernel** - copy kernel from image to TFTP

## SYNOPSIS
**ltsp-kernel** [**-h**] [**-i=**_initrd_] [**-k=**_kernel_] [**-n=**_name_] [**-p=**_partition_] [_image_] ...

## DESCRIPTION
Copy vmlinuz and initrd.img from an image or directory to TFTP.
If _image_ is unspecified, process all of them.
For simplicity, only directories (chroots) and raw images are supported,
either full filesystems (ext4 etc) or full disks (VMs). They may be sparse
to preserve space. Don't use a separate /boot nor LVM in disk images.
The targets will always be named vmlinuz and initrd.img to simplify boot.ipxe.

## OPTIONS
**-h**, **--help**
  Display a help message.

**-i**, **--initrd=**_path_
  Specify the initrd path; try to autodetect if undefined.

**-k**, **--kernel=**_path_
  Specify the kernel path; try to autodetect if undefined.

**-n**, **--name=**_name_
  Specify the image _name_; otherwise it defaults to the (parent, for
files) directory name; or to \`**uname -m**\` in the chrootless case.

**-p**, **--partition=**_number_
  _Image_ is a raw disk; the kernel/initrd is in partition _number_.

**--version**
  Display the version information.

## FILES
**/etc/ltsp/ltsp-kernel.conf**
  Supports [_image_] sections that allow to specify **INITRD=** and **KERNEL=**
directives on a per-image basis.

## ENVIRONMENT
All the long options can also be specified as environment variables in
UPPERCASE, for example:
```shell
PARTITION=1 ltsp-kernel ...
```

## EXAMPLES
```shell
ltsp-kernel -p 1 /srv/ltsp/x86_64/x86_64-flat.vmdk
```

## TODO
Meh, a paragraph is needed before bullets can properly function. Anyway:

* A lot of code will be shared between **ltsp-kernel**, **ltsp-image**
  (nee **ltsp-update-image**) and **ltsp-chroot**; maybe put them in ltsp/.
* **ltsp-chroot** will be needed for e.g. looking up the kernel name or
  running a quick **apt full-upgrade**.

## COPYRIGHT
Copyright 2019 the LTSP team, see https://github.com/ltsp/ltsp/graphs/contributors.

## SEE ALSO
**ltsp**(8), **ltsp.conf**(5)
