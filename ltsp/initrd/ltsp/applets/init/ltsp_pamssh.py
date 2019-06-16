#!/usr/bin/python3
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later
"""
Provide PAM authentication to a server via ssh and optionally $HOME with sshfs.
Also, provide an easy command for account merging (passwd/group).
"""
import re

# Names are from `man getpwent/getgrent`
# PW_GRNAME is the name of the primary group
# PW_MARK is True if this user must be preserved
PW_NAME = 0
PW_PASSWD = 1
PW_UID = 2
PW_GID = 3
PW_GECOS = 4
PW_DIR = 5
PW_SHELL = 6
PW_GRNAME = 7
PW_MARK = 8
GR_NAME = 0
GR_PASSWD = 1
GR_GID = 2
GR_MEM = 3


class MergePw:
    """Merge passwd and group from source directory "sdir" to "ddir".
    "sur" is a regex of source user accounts to import;
    "sgr" is a regex of source groups to import;
    "dur" is a regex of destination user accounts to preserve;
    "dgr" is a regex of destination groups to preserve;
    "sur" is merged with "sgr", and "dur" is merged with "dgr",
    but it's considered an error if there are collisions for the final merging.
    Using a regex allows one to define e.g.: "^(?!administrator)(a|b|c).*"
    which matches accounts starting from a, b, or c, but not administrator.
    Group regexes may also match system groups if they are prefixed with ":",
    e.g. ":sudo" matches all sudoers. Btw, ".*" = match all, "" = match none.
    All regexes default to none; except if sgr = "", then sur defaults to all.
    """
    def __init__(self, sdir, ddir, sur="", sgr="", dur="", dgr=""):
        self.spasswd, self.sgroup = self.read_dir(sdir)
        self.dpasswd, self.dgroup = self.read_dir(ddir)
        if not sur and not sgr:
            self.sur = ".*"
        else:
            self.sur = sur
        self.sgr = sgr
        self.dur = dur
        self.dgr = dgr
        # TODO: Read min_uid and max_uid from login.defs or default to 1000/60000.
        self.uid_min = 1000
        self.uid_max = 60000
        self.gid_min = 1000
        self.gid_max = 60000

    @staticmethod
    def read_dir(sdir):
        """Read passwd and group files into dictionaries"""
        # passwd is a dictionary with keys=PW_NAME string, values=PW_ENTRY list
        passwd = {}
        with open("{}/passwd".format(sdir), "r") as file:
            for line in file.readlines():
                pwe = line.strip().split(":")
                pwe.append("")  # PW_GRNAME, updated below
                pwe.append(False)  # PW_MARK
                # Convert uid/gid to ints to be able to do comparisons
                pwe[PW_UID] = int(pwe[PW_UID])
                pwe[PW_GID] = int(pwe[PW_GID])
                passwd[pwe[PW_NAME]] = pwe
        # g2n is a temporary dictionary to map from gid to group name
        # It's used to construct pwe[PW_GRNAME] and discarded after that
        g2n = {}
        # group is a dictionary with keys=GR_NAME string, values=GR_ENTRY list
        # Note that group["user"][GR_MEM] is a set of members (strings)
        group = {}
        with open("{}/group".format(sdir), "r") as file:
            for line in file.readlines():
                gr_entry = line.strip().split(":")
                gr_entry[GR_GID] = int(gr_entry[GR_GID])
                # Use set for group members, to avoid duplicates
                # Keep only non-empty group values
                gr_entry[GR_MEM] = set(
                    [x for x in gr_entry[GR_MEM].split(",") if x])
                group[gr_entry[GR_NAME]] = gr_entry
                # Construct g2n
                g2n[gr_entry[GR_GID]] = gr_entry[GR_NAME]
        # Usually system groups are like: "saned:x:121:"
        # while user groups frequently are like: ltsp:x:1000:ltsp
        # For simplicity, explicitly mention the primary user for all groups
        # In the same iteration, set pwe[PW_GRNAME]
        for pwn, pwe in passwd.items():
            grn = g2n[pwe[PW_GID]]
            pwe[PW_GRNAME] = grn
            if not pwn in group[grn][GR_MEM]:
                group[grn][GR_MEM].add(pwn)
        return (passwd, group)

    @staticmethod
    def save_dir(passwd, group, ddir="/tmp"):
        """Save the destination in ddir/passwd and ddir/group"""
        with open("{}/passwd".format(ddir), "w") as file:
            for pwe in passwd.values():
                file.write("{}:{}:{}:{}:{}:{}:{}\n".format(
                    pwe[PW_NAME], "ssh" if pwe[PW_MARK] else pwe[PW_PASSWD],
                    pwe[PW_UID], pwe[PW_GID], pwe[PW_GECOS], pwe[PW_DIR],
                    pwe[PW_SHELL]))
        with open("{}/group".format(ddir), "w") as file:
            for gre in group.values():
                file.write("{}:{}:{}:{}\n".format(gre[GR_NAME], gre[GR_PASSWD],
                                           gre[GR_GID], ",".join(gre[GR_MEM])))

    def mark_users(self, xpasswd, xgroup, xur, xgr):
        """Mark users in [sd]passwd that match the [sd]ur/[sd]gr regexes.
        Called twice, once for source and once for destination."""
        # Mark all users that match xgr
        if xgr:
            # grn = GRoup Name, gre = GRoup Entry
            for grn, gre in xgroup.items():
                if not self.gid_min <= gre[GR_GID] <= self.gid_max:
                    # Match ":sudo"; don't match "s.*"
                    # grnm = modified GRoup Name used for Matching
                    grnm = ":{}".format(grn)
                else:
                    grnm = grn
                # re.fullmatch needs Python 3.4 (xenial+ /jessie+)
                if not re.fullmatch(xgr, grnm):
                    continue
                for grm in gre[GR_MEM]:
                    xpasswd[grm][PW_MARK] = True
        # Mark all users that match xur
        if xur:
            for pwn, pwe in xpasswd.items():
                if not self.uid_min <= pwe[PW_UID] <= self.uid_max:
                    continue
                if re.fullmatch(xur, pwn):
                    xpasswd[pwn][PW_MARK] = True
        print("Marked users for |{}|{}|:".format(xur, xgr))
        for pwn, pwe in xpasswd.items():
            if pwe[PW_MARK]:
                print("", pwn, end="")
        print

    def merge(self):
        """Merge while storing the result to dpasswd/dgroup"""
        # Mark all destination users that match dur/dgr
        # Note that non-system groups that do match dgr
        # are discarded in the end if they don't have any members
        self.mark_users(self.dpasswd, self.dgroup, self.dur, self.dgr)

        # Remove the unmarked destination users
        print("Removed destination users:")
        for pwn in list(self.dpasswd):  # list() as we're removing items
            pwe = self.dpasswd[pwn]
            if not self.uid_min <= pwe[PW_UID] <= self.uid_max:
                continue
            if not self.dpasswd[pwn][PW_MARK]:
                print("", pwn, end="")
                del self.dpasswd[pwn]
        print()

        # Remove the destination non-system groups that are empty,
        # to allow source groups with the same gid to be merged
        # Do not delete primary groups
        print("Removed destination groups:")
        for grn in list(self.dgroup):  # list() as we're removing items
            gre = self.dgroup[grn]
            if not self.gid_min <= gre[GR_GID] <= self.gid_max:
                continue
            remove = True
            for grm in gre[GR_MEM]:
                if grm in self.dpasswd:
                    remove = False
                    break  # A member exists; continue with the next group
            if remove:
                print("", grn, end="")
                del self.dgroup[grn]
        print()

        # Mark all source users that match sur/sgr
        self.mark_users(self.spasswd, self.sgroup, self.sur, self.sgr)
        print()

        # Transfer all the marked users and their primary groups
        # Collisions in this step are considered fatal errors
        print("Transferred users:")
        for pwn, pwe in self.spasswd.items():
            if not pwe[PW_MARK]:
                continue
            if pwn in self.dpasswd:
                if pwe[PW_UID] != self.dpasswd[PW_UID] or \
                        pwe[PW_GID] != self.dpasswd[PW_GID]:
                    raise ValueError("PW_UID {} exists in destination".
                                     format(pwn))
            self.dpasswd[pwn] = pwe
            grn = pwe[PW_GRNAME]
            if grn in self.dgroup:
                if pwe[PW_GID] != self.dgroup[grn][GR_GID]:
                    raise ValueError("PW_GRNAME {} exists in destination".
                                     format(grn))
            self.dgroup[grn] = self.sgroup[grn]
            print("", pwn, end="")
        print()

        # Try to transfer all the additional groups that have marked members,
        # both system and non-system ones, and warn on collisions.
        print("Transferred groups:")
        for grn, gre in self.sgroup.items():
            transfer = False
            for grm in gre[GR_MEM]:
                if grm in self.spasswd and self.spasswd[grm][PW_MARK]:
                    transfer = True
                    break  # A member is marked; try to transfer
            if not transfer:
                continue
            if grn not in self.dgroup:
                self.dgroup[grn] = gre
            elif gre[GR_GID] == self.dgroup[grn][GR_GID]:
                # Same gids, just merge members without a warning
                self.dgroup[grn][GR_MEM].update(gre[GR_MEM])
            else:
                print(" [Warning: group {} has sgid={}, dgid={}; ".
                      format(grn, gre[GR_GID], self.dgroup[grn][GR_GID]),
                      end="")
                # If gids are different, keep sgid if dgid is not a system one
                if self.gid_min <= self.dgroup[grn][GR_GID] <= self.gid_max:
                    self.dgroup[grn][GR_GID] = grn[GR_GID]
                    print("keeping sgid]", end="")
                else:
                    print("keeping dgid]", end="")
            # In all cases, keep source group password
            self.dgroup[grn][GR_PASSWD] = gre[GR_PASSWD]
            print("", grn, end="")
        print()

        # Remove all unknown members from destination groups,
        # remove primary gids from group members,
        # and remove non-system groups that have no members
        umem = set()
        print("Removed unknown groups:")
        for grn in list(self.dgroup):  # list() as we're removing items
            gre = self.dgroup[grn]
            for grm in list(gre[GR_MEM]):
                if grm in self.dpasswd and \
                        self.dpasswd[grm][PW_GID] != gre[GR_GID]:
                    continue
                gre[GR_MEM].remove(grm)
                umem.add(grm)
            if not gre[GR_MEM]:
                if self.gid_min <= gre[GR_GID] <= self.gid_max:
                    del self.sgroup[grn]
                    print("", grn, end="")
        print()
        print("Removed unknown members:")
        print(umem)
        print()

def main():
    """Run the module from the command line"""
    mpw = MergePw("/etc", "/srv/ltsp/bionic-nfs/etc",
                  sur="^(?!administrator)(a|b|c).*", dur="f.*")
    mpw.merge()
    mpw.save_dir(mpw.dpasswd, mpw.dgroup)


if __name__ == "__main__":
    main()
