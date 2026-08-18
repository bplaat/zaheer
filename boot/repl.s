; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

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
