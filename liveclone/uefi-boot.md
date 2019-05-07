# Great documentation at:
https://www.rodsbooks.com/efi-bootloaders/secureboot.html#using_signed

# Bugs I reported:
Shim uses wrong TFTP server IP in proxyDHCP mode:
https://bugs.launchpad.net/ubuntu/+source/shim/+bug/1813541
Shim uses wrong TFTP server IP in proxyDHCP mode:
https://github.com/rhboot/shim/issues/165
Re: RFC Patch [0/2] PXE Add support for proxy DHCP:
https://lists.gnu.org/archive/html/grub-devel/2019-02/index.html
Wrong TFTP server when booted from proxyDHCP:
https://savannah.gnu.org/bugs/index.php?55636

# Results:
Secure netboot:
 * Only with shimx64.efi > gcdx64.efi > vmlinuz.
 * They should all be from the same distro, so that they use the same keys!
For non secure boot, iPXE is fine.
If mce ever manages to get ipxe.efi signed by MS, great! :D

# Plan:
Unzip 4 files in /efi/Boot:
bootx64.efi = some grub version - overrides the windows loader! keep backup!
grub.cfg
vmlinuz
initrd.img

# Common:
cmdpath=(hd0,gpt1)/efi/Boot

# gcdx64.efi.signed
# This probably means "grub cd"
prefix=(hd0,gpt1)/boot/grub
insmod ntfs
file /boot/grub/x86_64-efi/ntfs.mod not found
set root=memdisk
cat /grub.cfg
...it searches for /.disk/info and /.disk/mini-info
...then for $prefix/x86_64-efi/grub.cfg
...then for $prefix/grub.cfg
... and for $cmdpath/grub.cfg

# grubnetx64.efi.signed
# This is probably to be loaded from PXE/TFTP. It contains net modules.
prefix=(hd0,gpt1)/grub
insmod ntfs
file /grub/x86_64-efi/ntfs.mod not found
cat /grub.cfg
...then for $prefix/x86_64-efi/grub.cfg
...then for $prefix/grub.cfg

# grubx64.efi.signed
prefix=(hd0,gpt1)/EFI/ubuntu
NO memdisk, no grub.cfg!

# gsbx64.efi.signed
# Probably like grubx64, but only allows signed kernels.
# https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1401532
prefix=(hd0,gpt1)/EFI/ubuntu
NO memdisk, no grub.cfg!
