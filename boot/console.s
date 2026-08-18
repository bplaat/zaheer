; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

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
