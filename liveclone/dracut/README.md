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


# Other notes
mount --make-private

# Install 64bit kernel on 32bit installation
dpkg --add-architecture amd64
apt update
apt install linux-image-4.15.0-20-lowlatency:amd64 linux-headers-4.15.0-20-lowlatency:amd64
apt install --purge shim-signed:amd64


==> in masd-export-image, prefer `uname -m` to `dpkg --print-architecture` for the image name?

# Configuration directory structure (NOPE)
/etc/masd/
    by-section/
        default/
        old-monitor/
    by-host/
        ltsp123/
            etc/X11/xorg.conf
    by-ip/
        192.168.0/
        fe80::1/
    by-mac/
        a1:b2:c3:d4/
Those are copied to initrd-masd.img, and on boot merged to $rootmnt.
The conf file get on a separate tree and goes in /run.
/run/masd/overlays-merged/
            initrd/
            init/
            rc.local/


==> NOPE! Too complicated. If they want a couple of files, they can put them in
/etc/masd/initrd/moved-to-run/*
And then they can manually copy whatever they want with an lts.conf command
[01:02:*]
INIT_COMMAND_MV="cat /run/masd/hosts >> /etc/hosts"
