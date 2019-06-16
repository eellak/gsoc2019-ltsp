# PAM notes

## common-auth
PAM_TYPE=auth means that the user typed a password. At that point we can use
ssh to authenticate them, or sshfs to authenticate them and mount their home.

We mount their home if $SSHFS!=0 and :ssh: is in passwd and it's not already
mounted.

If seteuid is not passed to pam_exec, then running `su - user2` as user1,
can't sshfs-mount /home/user2 as TODO pam is running as user1?

Maybe running without seteuid, and with fuse allow_root, is the safest option.

## common-session open
PAM_TYPE=open_session means that a user switch has happened without the need of
a password. Examples:
 * Display manager autologin
 * (as root) `su - user`
 * Note, /etc/pam.d/sudo includes common-session-noninteractive,
   not common-session. This means it doesn't trigger `systemd --user`,
   it doesn't involve a seat etc. We probably shouldn't hook there,
   and document that `sudo -u user` doesn't sshfs-mount the home directory.

So, with autologins there's no prompt for password and we can't use sshfs.
Options:
 * Mention that autologins are only supported with NFS3 or local /home
   or any other method that mounts /home before the login process.
   This is much easier to implement and there's no need to store/manage
   cleartext passwords anywhere.
 * Tell the user to specify the password in cleartext somewhere, e.g. in
   LDM_PASSWORD=xxx. Then hook common-session and check if sshfs-mount is
   needed and the password is available, do it.

Let's only implement the first option for now.

## sshfs-unmount
Ideally, we can `fusermount -u /home/user` on PAM_TYPE=close_session if no user
processes are still running. In this case pam_exec must be listed after
pam_systemd, so that `systemd --user` has finished?
==> no, systemd --user is still running at that point; we'd need to delay
1 sec or exclude it, i.e. hacky code.
And maybe for the non-ideal cases like mate-session bugs, an LTSP hook
can pkill dbus-daemon etc, so that the pam related code is clean and constant.
HMMM systemd is probably using cgroups to see when to mount/unmount
/run/user/XXX
let's try to bind to that, it appears very consistent!

## KillUserProcesses - HERE
We want KillUserProcesses=yes because of various bugs in sessions etc.
It's doing a great job at killing processes.
It won't kill sshfs even if we run it with the user uid, as it's in a
different scope (we wouldn't want sshfs to die before user processes
get a chance to flush their file buffers).
We can't run fusermount on PAM_TYPE=session_close as KillUserProcesses
hasn't take effect yet. No, not even if we (sleep 5; fusermount) &
first; somehow systemd manages to wait that (cgroups/scopes?)
OOOOh wait, maybe on session_close we can run:
systemd-run on-different-scope 'sleep 5; check if /run/user gone; fusermount -u`
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

## To delete user settings, for benchmarking sshfs/nfs:
find ~ -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +
sshfs first login: 105 sec?!!
sshfs first logout: 30 sec, at_spi hang
sshfs second login: 6 sec
sshfs second logout: 1 sec
(clear again)
sshfs third login: 120 sec?!!
sshfs third logout: 30 sec, at_spi hang
-o kernel_cache => 114, meh
nfs first login: 7 sec
firefox: 6 sec

## pam_mount, autofs, ipsec
Those don't sound very suitable; but here's a link for pam_mount and sshfs:
https://sourceforge.net/p/fuse/mailman/message/32563925/
http://manpages.ubuntu.com/manpages/bionic/man8/pam_mount.8.html
http://manpages.ubuntu.com/manpages/bionic/man5/pam_mount.conf.5.html
