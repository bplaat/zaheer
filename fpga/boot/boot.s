; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

.equ STACK_TOP,      0x20001000
.equ UART_TX_DATA,   0x40000000
.equ UART_TX_STATUS, 0x40000004
.equ UART_RX_STATUS, 0x40000008
.equ UART_RX_DATA,   0x4000000C
.equ LED_REG,        0x60000000
.equ VIDEO_BASE,     0x80000000
.equ VIDEO_END,      0x80002580
.equ VIDEO_LAST_ROW, 0x800024e0
.equ VIDEO_COLS,     80
.equ VIDEO_ROWS,     60
.equ VIDEO_ROW_BYTES, 160
.equ VIDEO_BLANK,    0x07200720
.equ BUF_ADDR,       0x20000000
.equ BUF_MAX,        255

_start:
    ; Set stack pointer
    lui sp, %hi(STACK_TOP)
    addi sp, sp, %lo(STACK_TOP)

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

repl:
    ; Print prompt
    la a0, str_prompt
    jal ra, print_string

    ; s0 = current write position, s1 = buffer start
    li s0, BUF_ADDR
    li s1, BUF_ADDR

read_loop:
    ; Poll UART RX status
    li t0, UART_RX_STATUS
wait_rx:
    lw t1, 0(t0)
    andi t1, t1, 1
    beq t1, zero, wait_rx

    ; Read received byte
    li t0, UART_RX_DATA
    lbu a0, 0(t0)

    ; Handle Enter (\r = 13)
    addi t1, zero, 13
    beq a0, t1, enter_pressed

    ; Handle Enter (\n = 10)
    addi t1, zero, 10
    beq a0, t1, enter_pressed

    ; Handle backspace (8)
    addi t1, zero, 8
    beq a0, t1, do_backspace

    ; Handle DEL (127)
    addi t1, zero, 127
    beq a0, t1, do_backspace

    ; Ignore if buffer full
    sub t2, s0, s1
    addi t3, zero, BUF_MAX
    bge t2, t3, read_loop

    ; Echo char and store in buffer
    jal ra, print_char
    sb a0, 0(s0)
    addi s0, s0, 1
    j read_loop

do_backspace:
    beq s0, s1, read_loop     ; nothing to erase
    addi s0, s0, -1
    addi a0, zero, 8
    jal ra, print_char
    addi a0, zero, 32
    jal ra, print_char
    addi a0, zero, 8
    jal ra, print_char
    j read_loop

enter_pressed:
    sb zero, 0(s0)            ; null-terminate buffer
    la a0, str_crlf
    jal ra, print_string

    ; Dispatch the "char" command.
    lbu t0, 0(s1)
    addi t1, zero, 99         ; 'c'
    bne t0, t1, echo_command
    lbu t0, 1(s1)
    addi t1, zero, 104        ; 'h'
    bne t0, t1, echo_command
    lbu t0, 2(s1)
    addi t1, zero, 97         ; 'a'
    bne t0, t1, echo_command
    lbu t0, 3(s1)
    addi t1, zero, 114        ; 'r'
    bne t0, t1, echo_command
    lbu t0, 4(s1)
    bne t0, zero, echo_command
    jal ra, command_char
    j repl

echo_command:
    mv a0, s1
    jal ra, print_string
    la a0, str_crlf
    jal ra, print_string
    j repl

; Display all 256 font glyphs as a 16 x 16 grid. Using print_glyph instead of
; print_char makes control-code glyphs visible on the text display.
command_char:
    mv s7, ra
    addi s8, zero, 0
command_char_loop:
    mv a0, s8
    jal ra, print_glyph
    addi s8, s8, 1
    andi t0, s8, 15
    bne t0, zero, command_char_next
    la a0, str_crlf
    jal ra, print_string
command_char_next:
    addi t0, zero, 256
    blt s8, t0, command_char_loop
    mv ra, s7
    ret

; Print null-terminated string pointed to by a0
print_string:
    mv s5, a0
    mv s6, ra
print_str_loop:
    lbu a0, 0(s5)
    beq a0, zero, print_str_done
    jal ra, print_char
    addi s5, s5, 1
    j print_str_loop
print_str_done:
    mv ra, s6
    ret

; Print single char in a0
print_char:
    li t2, UART_TX_DATA
    li t3, UART_TX_STATUS
print_char_wait:
    lw t1, 0(t3)
    andi t1, t1, 1
    bne t1, zero, print_char_wait
    sb a0, 0(t2)

    ; Carriage return moves to column zero without changing rows.
    addi t0, zero, 13
    beq a0, t0, video_carriage_return

    ; Line feed advances one row and retains the current column.
    addi t0, zero, 10
    beq a0, t0, video_line_feed

    ; Backspace only moves within the current row. The REPL emits the usual
    ; backspace-space-backspace sequence to erase a character.
    addi t0, zero, 8
    beq a0, t0, video_backspace

video_write_glyph:
    ; Store a character using light grey on black (attribute 0x07).
    li t0, 0x0700
    or t0, t0, a0
    sh t0, 0(s2)
    addi s2, s2, 2
    addi s3, s3, 1
    addi t0, zero, VIDEO_COLS
    blt s3, t0, video_done
    addi s3, zero, 0
    addi s4, s4, 1
    j video_check_scroll

; Print a glyph without interpreting control character values on the video
; display. The raw byte is still mirrored to UART.
print_glyph:
    li t2, UART_TX_DATA
    li t3, UART_TX_STATUS
print_glyph_wait:
    lw t1, 0(t3)
    andi t1, t1, 1
    bne t1, zero, print_glyph_wait
    sb a0, 0(t2)
    j video_write_glyph

video_carriage_return:
    slli t0, s3, 1
    sub s2, s2, t0
    addi s3, zero, 0
    ret

video_line_feed:
    addi s2, s2, VIDEO_ROW_BYTES
    addi s4, s4, 1
    j video_check_scroll

video_backspace:
    beq s3, zero, video_done
    addi s2, s2, -2
    addi s3, s3, -1
    ret

video_check_scroll:
    addi t0, zero, VIDEO_ROWS
    blt s4, t0, video_done

    ; Copy rows 1-59 over rows 0-58 using two cells per word.
    li t0, VIDEO_BASE
    addi t1, t0, VIDEO_ROW_BYTES
    li t2, VIDEO_END
video_scroll_loop:
    lw t3, 0(t1)
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 4
    blt t1, t2, video_scroll_loop

    ; Clear the final row and place the cursor at the retained column.
    li t1, VIDEO_END
    li t2, VIDEO_BLANK
video_clear_last_row:
    sw t2, 0(t0)
    addi t0, t0, 4
    blt t0, t1, video_clear_last_row
    li s2, VIDEO_LAST_ROW
    slli t0, s3, 1
    add s2, s2, t0
    addi s4, zero, 59

video_done:
    ret

str_banner:
    .asciz "Zaheer REPL\r\n"
str_prompt:
    .asciz "> "
str_crlf:
    .asciz "\r\n"
