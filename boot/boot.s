; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

.include "consts.s"

_start:
    ; Set stack pointer
    lui sp, %hi(STACK_TOP)
    addi sp, sp, %lo(STACK_TOP)

    ; Copy the font embedded in boot ROM to writable Taro font RAM.
    la t0, font_data
    li t1, FONT_BASE
    li t2, FONT_END
font_load_loop:
    lw t3, 0(t0)
    sw t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    blt t1, t2, font_load_loop

    ; Clear text video RAM and initialise the cursor.
    li t0, VIDEO_BASE
    li t1, VIDEO_END
    li t2, VIDEO_BLANK
video_clear_loop:
    sw t2, 0(t0)
    addi t0, t0, 4
    blt t0, t1, video_clear_loop
    li s2, VIDEO_BASE          ; cursor cell address
    addi s3, zero, 0           ; cursor column
    addi s4, zero, 0           ; cursor row

    ; Turn on first LED
    li t0, LED_REG
    addi t1, zero, 1
    sw t1, 0(t0)

    ; Print banner
    la a0, str_banner
    jal ra, print_string

    ; Turn on all LEDs
    li t0, LED_REG
    addi t1, zero, 0x3f
    sw t1, 0(t0)

.include "repl.s"
.include "console.s"

str_banner:
    .asciz "Zaheer REPL\r\n"
str_prompt:
    .asciz "> "
str_crlf:
    .asciz "\r\n"

.balign 4
font_data:
    .incbin "../fpga/taro/font.pf"
