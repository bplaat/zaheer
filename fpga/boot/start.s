#
# Copyright (c) 2025 Bastiaan van der Plaat
#
# SPDX-License-Identifier: MIT
#

.equ UART_TX_DATA, 0x00800000

.section .text._start

_start:

    la   t0, 0x20
    li   t1, 'y'
    sb   t1, 0(t0)

    lb   t2, 0(t0)
    li   t3, UART_TX_DATA
    sb   t2, 0(t3)

    j _start

    /*li sp, 0x200
    j boot_main*/

.data

placeholder:
    .word 0
