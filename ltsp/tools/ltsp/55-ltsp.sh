# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Placeholder for distributions/users to override upstream ltsp.sh functions.

main_ltsp() {
    source_tool "$LTSP_TOOL" "$@"
    # All tools are required to have a main
    main "$@"
}
