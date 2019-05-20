# Questions for vagrantc
## Journal
        rw sed "s|[^[alpha]]*Storage=.*|Storage=none|" \
            -i "$rootmnt/etc/systemd/journald.conf"
Storage=none or volatile?

## Authentication, homes
The following can work without sshfs nor ssh authentication:
* local home
* nfsmount server:/home /root/home (from initramfs or real system)
* nfsmount + encryption => can delete but not read?
* maybe cifs?
* nfsv4 with kerberos etc, safe
* live session, home in ram

Otherwise we need pam/ldm/something.
How about autologin dm as ltsp, who has a session "ltsp", who presents ldm?
This allows us to bypass screen handling, wayland setup, whatever.
Also, search other pams, maybe someone will do, e.g. unlock nfshome/username/somefile?

# Various TODO notes
* use "nocache" for ltsp-update-image, see /etc/cron.daily/mlocate
* systemd.conf files use TitleCase=yes, should we do that for lts.conf?
  Maybe it's a good compromise, to have these in the environment for quick
  things like `env | grep TitleCase.*= >> file`, and then to remove all
  TitleCase vars before spawning shell sessions etc.
