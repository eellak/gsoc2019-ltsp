#!/usr/bin/python3
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later
"""
Usage: mergepw [--sur=] [--sgr=] [--dur=] [--dgr=] sdir ddir mdir

Merge specified users and groups as follows:
 * Read source directory passwd, group and *optionally* shadow and gshadow;
   if source shadow files are missing fill them with default values
 * Read destination directory passwd, group, shadow and gshadow
 * Merge them and write the result to the directory "mdir"

Options:
  --sur: a regex of source user accounts to import
  --sgr: a regex of source groups; their member users are also imported
  --dur: a regex of destination user accounts to preserve
  --dgr: a regex of destination groups; their member users are also preserved
  -q,--quiet: only show warnings and errors

If UIDs or primary GIDs collide in the final merging, execution is aborted.
Using a regex allows one to define e.g.: "^(?!administrator)(a|b|c).*",
which matches accounts starting from a, b, or c, but not administrator.
Group regexes may also match system groups if they are prefixed with ":",
e.g. ":sudo" matches all sudoers. Btw, ".*" = match all, "" = match none.
All regexes default to none; except if sgr = "", then sur defaults to all.
"""
from datetime import datetime
import getopt
import os
import re
import sys

# Names are from `man getpwent/getgrent/getspent/getsgent`
# PW_GRNAME is the name of the primary group
# PW_MARK is True if this user must be preserved
PW_NAME = 0
PW_PASSWD = 1
PW_UID = 2
PW_GID = 3
PW_GECOS = 4
PW_DIR = 5
PW_SHELL = 6
# SP_NAMP is the same as PW_NAME so we ignore it
SP_PWDP = 7
SP_LSTCHG = 8
SP_MIN = 9
SP_MAX = 10
SP_WARN = 11
SP_INACT = 12
SP_EXPIRE = 13
SP_FLAG = 14
# These additional fields are for internal use
PW_GRNAME = 15  # The group name of the user
PW_MARK = 16  # Boolean, True if the user is marked to import/preserve
# Default values when source shadow doesn't exist:
SP_DEFS = ["*", (datetime.utcnow() - datetime(1970, 1, 1)).days,
           0, 99999, 7, "", "", "", "", False]
GR_NAME = 0
GR_PASSWD = 1
GR_GID = 2
GR_MEM = 3
# SG_NAMP is the same as GR_NAME so we ignore it
SG_PASSWD = 4
# Currently we process SG_ADM (group administrator list) as a simple string;
# file a bug report if you need it properly merged:
SG_ADM = 5
# SG_MEM is the same as GR_MEM so we ignore it
# Default values when source gshadow doesn't exist:
SG_DEFS = ["*", ""]

QUIET = False

def log(*args, end='\n', error=False):
    """Print errors to stderr; print everything if --quiet wasn't specified"""
    if error or not QUIET:
        print(*args, end=end, file=sys.stderr)

class MergePw:
    """Merge passwd and group from source directory "sdir" to "ddir"."""
    def __init__(self, sdir, ddir, mdir, sur="", sgr="", dur="", dgr=""):
        self.spasswd, self.sgroup = self.read_dir(sdir)
        self.dpasswd, self.dgroup = self.read_dir(ddir)
        self.mdir = mdir
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
        """Read sdir/{passwd,group,shadow,gshadow} into dictionaries"""
        # passwd is a dictionary with keys=PW_NAME string, values=PW_ENTRY list
        passwd = {}
        with open("{}/passwd".format(sdir), "r") as file:
            for line in file.readlines():
                pwe = line.strip().split(":")
                if len(pwe) != 7:
                    raise ValueError("Invalid passwd line:\n{}".format(line))
                # Add defaults in case shadow doesn't exist
                pwe += SP_DEFS
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
                gre = line.strip().split(":")
                if len(gre) != 4:
                    raise ValueError("Invalid group line:\n{}".format(line))
                # Add defaults in case gshadow doesn't exist
                gre += SG_DEFS
                gre[GR_GID] = int(gre[GR_GID])
                # Use set for group members, to avoid duplicates
                # Keep only non-empty group values
                gre[GR_MEM] = set(
                    [x for x in gre[GR_MEM].split(",") if x])
                group[gre[GR_NAME]] = gre
                # Construct g2n
                g2n[gre[GR_GID]] = gre[GR_NAME]
        # Usually system groups are like: "saned:x:121:"
        # while user groups frequently are like: ltsp:x:1000:ltsp
        # For simplicity, explicitly mention the primary user for all groups
        # In the same iteration, set pwe[PW_GRNAME]
        for pwn, pwe in passwd.items():
            grn = g2n[pwe[PW_GID]]
            pwe[PW_GRNAME] = grn
            if not pwn in group[grn][GR_MEM]:
                group[grn][GR_MEM].add(pwn)
        # If shadow exists and is accessible, include its information
        if os.access("{}/shadow".format(sdir), os.R_OK):
            with open("{}/shadow".format(sdir), "r") as file:
                for line in file.readlines():
                    pwe = line.strip().split(":")
                    if len(pwe) != 9:
                        # It's invalid; displaying it isn't a security issue
                        raise ValueError(
                            "Invalid shadow line:\n{}".format(line))
                    if pwe[0] in passwd:
                        # List slice
                        passwd[pwe[0]][SP_PWDP:SP_FLAG+1] = pwe[1:9]
        # If gshadow exists and is accessible, include its information
        if os.access("{}/gshadow".format(sdir), os.R_OK):
            with open("{}/gshadow".format(sdir), "r") as file:
                for line in file.readlines():
                    gre = line.strip().split(":")
                    if len(gre) != 4:
                        # It's invalid; displaying it isn't a security issue
                        raise ValueError(
                            "Invalid gshadow line:\n{}".format(line))
                    if gre[0] in group:
                        # List slice
                        group[gre[0]][SG_PASSWD:SG_ADM+1] = gre[1:3]

        return (passwd, group)

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
        for pwn, pwe in xpasswd.items():
            try:
                if pwe[PW_MARK]:
                    log("", pwn, end="")
            except:
                print("ERRRROR", pwe)
        log()

    def merge(self):
        """Merge while storing the result to dpasswd/dgroup"""
        # Mark all destination users that match dur/dgr
        # Note that non-system groups that do match dgr
        # are discarded in the end if they don't have any members
        log("Marked destination users for regexes '{}', '{}':".format(
            self.dur, self.dgr))
        self.mark_users(self.dpasswd, self.dgroup, self.dur, self.dgr)

        # Remove the unmarked destination users
        log("Removed destination users:")
        for pwn in list(self.dpasswd):  # list() as we're removing items
            pwe = self.dpasswd[pwn]
            if not self.uid_min <= pwe[PW_UID] <= self.uid_max:
                continue
            if not self.dpasswd[pwn][PW_MARK]:
                log("", pwn, end="")
                del self.dpasswd[pwn]
        log()

        # Remove the destination non-system groups that are empty,
        # to allow source groups with the same gid to be merged
        # Do not delete primary groups
        log("Removed destination groups:")
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
                log("", grn, end="")
                del self.dgroup[grn]
        log()

        # Mark all source users that match sur/sgr
        log("Marked source users for regexes '{}', '{}':".format(
            self.sur, self.sgr))
        self.mark_users(self.spasswd, self.sgroup, self.sur, self.sgr)

        # Transfer all the marked users and their primary groups
        # Collisions in this step are considered fatal errors
        log("Transferred users:")
        for pwn, pwe in self.spasswd.items():
            if not pwe[PW_MARK]:
                continue
            if pwn in self.dpasswd:
                if pwe[PW_UID] != self.dpasswd[PW_UID] or \
                        pwe[PW_GID] != self.dpasswd[PW_GID]:
                    raise ValueError(
                        "PW_[UG]ID for {} exists in destination".format(pwn))
            self.dpasswd[pwn] = pwe
            grn = pwe[PW_GRNAME]
            if grn in self.dgroup:
                if pwe[PW_GID] != self.dgroup[grn][GR_GID]:
                    raise ValueError(
                        "GR_GID for {} exists in destination".format(grn))
            self.dgroup[grn] = self.sgroup[grn]
            log("", pwn, end="")
        log()

        # Try to transfer all the additional groups that have marked members,
        # both system and non-system ones, and warn on collisions
        log("Transferred groups:")
        needeol = False
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
                log(" [WARNING: group {} has sgid={}, dgid={}; ".
                    format(grn, gre[GR_GID], self.dgroup[grn][GR_GID]),
                    end="", error=True)
                # If gids are different, keep sgid if dgid is not a system one
                if self.gid_min <= self.dgroup[grn][GR_GID] <= self.gid_max:
                    self.dgroup[grn][GR_GID] = grn[GR_GID]
                    log("keeping sgid]", end="", error=True)
                else:
                    log("keeping dgid]", end="", error=True)
                needeol = True
            # In all cases, keep source group password
            self.dgroup[grn][GR_PASSWD] = gre[GR_PASSWD]
            log("", grn, end="")
        log(error=needeol)

        # Remove all unknown members from destination groups,
        # remove primary gids from group members,
        # and remove non-system groups that have no members
        umem = set()
        log("Removed unknown groups:")
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
                    log("", grn, end="")
        log()
        log("Removed unknown members:")
        for grm in umem:
            log("", grm, end="")
        log()

    def save(self):
        """Save the merged result in mdir/{passwd,group,shadow,gshadow}"""
        with open("{}/passwd".format(self.mdir), "w") as file:
            for pwe in self.dpasswd.values():
                file.write("{}:{}:{}:{}:{}:{}:{}\n".format(
                    pwe[PW_NAME], "ssh" if pwe[PW_MARK] else pwe[PW_PASSWD],
                    *pwe[PW_UID:PW_SHELL+1]))
        with open("{}/group".format(self.mdir), "w") as file:
            for gre in self.dgroup.values():
                file.write("{}:{}:{}:{}\n".format(
                    gre[GR_NAME], gre[GR_PASSWD], gre[GR_GID],
                    ",".join(gre[GR_MEM])))
        with open("{}/shadow".format(self.mdir), "w") as file:
            for pwe in self.dpasswd.values():
                file.write("{}:{}:{}:{}:{}:{}:{}:{}:{}\n".format(
                    pwe[PW_NAME], *pwe[SP_PWDP:SP_FLAG+1]))
        with open("{}/gshadow".format(self.mdir), "w") as file:
            for gre in self.dgroup.values():
                file.write("{}:{}:{}:{}\n".format(
                    gre[GR_NAME], *gre[SG_PASSWD:SG_ADM+1],
                    ",".join(gre[GR_MEM])))
        # TODO: chmod/chown

def main(argv):
    """Run the module from the command line"""
    global QUIET
    try:
        opts, args = getopt.getopt(
            argv[1:], "q", ["quiet", "sur=", "sgr=", "dur=", "dgr="])
    except getopt.GetoptError as err:
        print("Error in command line parameters:", err, file=sys.stderr)
        args = []  # Trigger line below
    if len(args) != 3:
        print(__doc__.strip())
        sys.exit(1)
    dopts = {}
    for key, val in opts:
        if key == "-q" or key == "--quiet":
            QUIET = True
        elif key.startswith("--"):
            dopts[key[2:]] = val
        else:
            raise ValueError("Unknown parameter: ", key, val)
    mpw = MergePw(args[0], args[1], args[2], **dopts)
    mpw.merge()
    mpw.save()


if __name__ == "__main__":
    main(sys.argv)
