# Currently working on
* Implement ltsp-kernels, ltsp-initrd
* Move away from 55-num to hooks:
  rw run_hook hook_function "$@"
* Implement init-ltsp.d as a tool
* Move the current ltsp code there
* See casper scripts, e.g. disabling snapd updates


# Questions for vagrantc
* ...I disabled rsyslogd and limited journal to 1M
* Server creates something like a .zip file with password (gpg, whatever).
  Clients need to enter password to unzip it.
  This then contains the user shadow entry or his private ssh key etc.
  Meh or just authenticate to the server via https.
  Isn't there any pam modules for that...

# Issues seen
* buster gives a splash screen and hangs some times.
  This is due to the /dev mount not being moved;
  maybe because /loop0p1 is in use? But /sda1 works...

## Authentication, homes
The following can work without sshfs nor ssh authentication:
* local home
* live session, home in ram
* nfsmount server:/home /root/home (from initramfs or real system)
* nfsmount + encryption => can delete but not read?
  - ecryptfs isn't preinstalled
* mount.cifs exists in ubuntu live CDs (for /home), but not in the initramfs
* nfsv4 with kerberos etc, safe

Otherwise we need pam/ldm/something.
How about autologin dm as ltsp, which has a session "ltsp", that presents ldm?
This allows us to bypass screen handling, wayland setup, whatever.
Also, search other pams, maybe someone will do, e.g. unlock nfshome/username/somefile?
Btw: `md5sum /sys/firmware/dmi/tables/DMI`


# Various TODO notes
* use "nocache" for ltsp-update-image, see /etc/cron.daily/mlocate
* and private mounts
* systemd.conf files use TitleCase=yes, should we do that for lts.conf?
  Maybe it's a good compromise, to have these in the environment for quick
  things like `env | grep TitleCase.*= >> file`, and then to remove all
  TitleCase vars before spawning shell sessions etc.

