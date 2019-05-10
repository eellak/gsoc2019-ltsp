# Dracut support for MASD

## Generate the initramfs
$ yum install nbd
$ dracut --list-modules
$ dracut [--kver=$(uname -r)] --no-hostonly --force --[force-]add "nbd nfs squash dmsquash-live" --add-drivers "nbd aoe squashfs"
# network base overlay:unneeded, I pull it from /sysroot

dracut-state with netroot:
netroot=nbd:blabla
root=block:/dev/root
and fails.

dracut-state with root=nbd:bla
same! i pass root=, it becomes netroot=
but, it works!

root=/dev/nbd0 netroot=bla
root=block:/dev/nbd0
and hangs


## Notes on default fedora 30 initrd
It's based on Bash and GNU tools. It's missing the following:
    basename blockdev busybox chmod cpio cut date dd env expr find hostname
    ipconfig mkswap mktemp modprobe aoe nbd-client nc netstat nfsmount
    partprobe pgrep pidof pivot_root rmdir run-parts seq ss sync touch wget
    which
It does have these though:
    blkid dhclient ip
So... maybe the LTSP initramfs code should really be MINIMAL!
That also means, NOT relying on ltsp.sh.
The ltsp-client code should run later on by setting init= or similar.

Hey, maybe a separate ltsp-initramfs.conf makes more sense?
Do we really need one now that it's minimal?
Let's see what code runs on initramfs:
 * patch_nbd
 * writeable_root ==> not even needed if doing switch_root from init
 * set_init ==> not needed if init= is used; although ltsp-init should be there then

### Results
Keep about the current code in the initramfs:
 * Patch initramfs-tools when necessary (nbd...).
 * Do the tmpfs overlay in /run/initramfs/cow, because systemd doesn't unmount
   /run/initramfs/* on shutdown.
 * Put the LTSP code in the tmpfs overlay, because initramfs-tools uses
   noexec for /run/initramfs. Then symlink to /run/ltsp if necessary.
 * Move $rootmnt/sbin/init to init.real; symlink it to /run/ltsp/ltsp.sh;
   then from the init ltsp tool, put init.real back.
 * If 00-overlay is ever needed, we'll manage. Don't care about it now.
 * All the ltsp_config.d and init-ltsp.d code will run from the ltsp init tool.
 TO READ: https://www.slax.org/blog/24229-Clean-shutdown-with-systemd.html

# Other notes
mount --make-private
Fetch ltsp.img/ltsp-client.sh via nbd (!)

# Install 64bit kernel on 32bit installation
dpkg --add-architecture amd64
apt update
apt install linux-image-4.15.0-20-lowlatency:amd64 linux-headers-4.15.0-20-lowlatency:amd64
apt install --purge shim-signed:amd64
