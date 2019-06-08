## NAME
**ltsp kernel** - copy kernel from image to TFTP

## SYNOPSIS
**ltsp kernel** [**-h**] [**-i=**_initrd_] [**-k=**_kernel_] [**-n=**_name_] [**-p=**_partition_] [-V] [_image_] ...

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
  Specify the kernel glob; try to autodetect if undefined.

**-n**, **--name=**_name_
  Specify the image _name_; otherwise it defaults to the (parent, for
files) directory name; or to \`**uname -m**\` in the chrootless case.

**--version**
  Display the version information.

## FILES
**/etc/ltsp/kernel.conf**
  **INITRD=** and **KERNEL=** directives can be specified for all images
centrally or on a per-image basis under [_image_] sections.

## ENVIRONMENT
All the long options can also be specified as environment variables in
UPPERCASE, for example:
```shell
KERNEL=/boot/vmlinuz ltsp kernel ...
```

## EXAMPLES
```shell
ltsp kernel -p 1 /srv/ltsp/x86_64/x86_64-flat.vmdk
```
