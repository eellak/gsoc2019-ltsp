#!/usr/bin/python3
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later
"""
Provide PAM authentication to a server via ssh and optionally $HOME with sshfs.
Also, provide an easy command for account merging (passwd/group).
"""
import re

class MergePw:
    """Merge passwd and group from source "sdir" directory to "ddir".
    "fetch" is a regex of remote user accounts to import;
    "keep" is a regex of local user accounts to preserve;
    it's considered an error if these users/uids/gids overlap.
    Using a regex allows one to define e.g.: '^(?!administrator)(a|b|c).*'
    which matches accounts starting from a, b, or c, but not administrator.
    Algorithm:
    * Read min_uid and max_uid from login.defs or default to 1000/60000.
    * Remove all dest users except "keep".
    * Remove all unused dest groups; no collisions so far.
    * For each remote user that matches,
      - migrate uid/gid if it's available; error otherwise
    * For each remote group that now isn't a user gid,
      - if it's non-system, migrate if possible, warn otherwise.
      - if it's system group, migrate if:
        + a target account user needs it,
        + the group name doesn't exist in the target,
        + the group gid is free (e.g. NFS group shares;
          no point in different gids); warn otherwise.
    Χμμ μήπως για την ώρα να το κάνω με init command create user
    και όλο το βαρύ merging να το δω ΑΦΟΥ δω ότι δουλεύει
    ΟΚ. Άρα να ξεκινήσω από το ssh auth κομμάτι πρώτα.
    """
    def __init__(self, sdir, ddir, fetch=".*", keep=".*"):
        self.spasswd, self.sgroup = self.read_dir(sdir)
        self.dpasswd, self.dgroup = self.read_dir(ddir)
        self.regex = regex

    @staticmethod
    def read_dir(sdir):
        """Read passwd and group into dictionaries"""
        passwd = {}
        with open("{}/passwd".format(sdir), 'r') as file:
            for line in file.readlines():
                line = line.strip()
                passwd[line.split(":")[0]] = line
        group = {}
        with open("{}/group".format(sdir), 'r') as file:
            for line in file.readlines():
                line = line.strip()
                group[line.split(":")[0]] = line
        return (passwd, group)

    def merge(self):
        """Output the merged result"""
        mpasswd = {}
        removedu = []
        for user in self.spasswd:
            uid, gid = [int(x) for x in self.spasswd[user].split(":")[2:4]]
            if uid >= self.uid_min and uid <= self.uid_max:
                if re.search(self.regex, user):
                    mpasswd[user] = self.spasswd[user]
                else:
                    removedu.append(user)
        for user in mpasswd:
            print(mpasswd[user])
        print("Removed users: ", removedu)

def main():
    """Run the module from the command line"""
    mpw = MergePw("/etc", "/srv/ltsp/bionic-nfs/etc",
                  "^(?!administrator)(a|b|c).*")
    mpw.merge()


if __name__ == '__main__':
    main()

"""
# Pam notes

## common-auth
In common-auth we replace the pam_unix line with those two:

auth [success=2 default=ignore] pam_unix.so nullok_secure
auth [success=1 default=ignore] pam_exec.so stdout expose_authtok /usr/local/bin/pamssh
(we expect the next line to be pam_deny)

That means "authenticate locally, if it's a local user; remotely if not"

## auth list
Do we need to maintain the list of users to be authenticated on the
server? If so, maybe just use "ssh" instead of "*" in shadow?
"""
