## NAME
**ltsp kernel** - copy kernel from image to TFTP

## SYNOPSIS
**ltsp** [_ltsp-options_] **kernel** [**-k=**_kernel-initrd_] [_image_] ...

## DESCRIPTION
Copy vmlinuz and initrd.img from an image or chroot to TFTP.
If _image_ is unspecified, process all of them.
For simplicity, only chroots and raw images are supported, either full
filesystems (squashfs, ext4) or full disks (flat VMs). They may be sparse
to preserve space. Don't use a separate /boot nor LVM in disk images.
The targets will always be named vmlinuz and initrd.img to simplify boot.ipxe.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-k**, **--kernel-initrd=**_line_
  Specify a kernel glob and an initrd regex to locate them inside the _image_;
  try to autodetect if undefined. See the EXAMPLES section below.

## EXAMPLES
Typical use:
```shell
ltsp kernel x86_64
```

Passing a glob to locate the kernel and a regex to locate the initrd in a
Debian live CD:
```shell
ltsp -k"live/vmlinuz-* s|vmlinuz|initrd.img|"
```
