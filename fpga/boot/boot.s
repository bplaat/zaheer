; Copyright (c) 2025-2026 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

.equ STACK_TOP,      0x20001000
.equ UART_TX_DATA,   0x40000000
.equ UART_TX_STATUS, 0x40000004
.equ UART_RX_STATUS, 0x40000008
.equ UART_RX_DATA,   0x4000000C
.equ LED_REG,        0x60000000
.equ BUF_ADDR,       0x20000000
.equ BUF_MAX,        255

_start:
    ; Set stack pointer
    lui sp, %hi(STACK_TOP)
    addi sp, sp, %lo(STACK_TOP)

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
    mv a0, s1
    jal ra, print_string
    la a0, str_crlf
    jal ra, print_string
    j repl

; Print null-terminated string pointed to by a0
print_string:
    li t2, UART_TX_DATA
    li t3, UART_TX_STATUS
print_str_loop:
    lbu t0, 0(a0)
    beq t0, zero, print_str_done
print_str_wait:
    lw t1, 0(t3)
    andi t1, t1, 1
    bne t1, zero, print_str_wait
    sb t0, 0(t2)
    addi a0, a0, 1
    j print_str_loop
print_str_done:
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
    ret

str_banner:
    .asciz "Zaheer REPL\r\n"
str_prompt:
    .asciz "> "
str_crlf:
    .asciz "\r\n"
