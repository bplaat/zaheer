#
# Copyright (c) 2025 Bastiaan van der Plaat
#
# SPDX-License-Identifier: MIT
#

.section .text._start

_start:
    li sp, 0x2000
    j boot_main
