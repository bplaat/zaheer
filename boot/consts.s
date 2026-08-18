; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

.equ STACK_TOP,       0x20001000
.equ UART_TX_DATA,    0x40000000
.equ UART_TX_STATUS,  0x40000004
.equ UART_RX_STATUS,  0x40000008
.equ UART_RX_DATA,    0x4000000C
.equ LED_REG,         0x60000000
.equ VIDEO_BASE,      0x80000000
.equ VIDEO_END,       0x80002580
.equ VIDEO_LAST_ROW,  0x800024e0
.equ VIDEO_COLS,      80
.equ VIDEO_ROWS,      60
.equ VIDEO_ROW_BYTES, 160
.equ VIDEO_BLANK,     0x07200720
.equ BUF_ADDR,        0x20000000
.equ BUF_MAX,         255
