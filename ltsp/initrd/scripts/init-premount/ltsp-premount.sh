#!/bin/sh
# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Initramfs-tools hook to call main_ltsp_premount
. /scripts/ltsp-functions.sh
main_ltsp_premount "$@"
