; Copyright (c) 2025 Bastiaan van der Plaat
; SPDX-License-Identifier: MIT

.equ STACK_TOP, 0x20001000
.equ UART_TX_DATA, 0x40000000
.equ UART_TX_STATUS, 0x40000004
.equ LED_REG, 0x60000000

_start:
    ; Set stack pointer
    lui sp, %hi(STACK_TOP)
    addi sp, sp, %lo(STACK_TOP)

    ; Turn on first LED
    li t0, LED_REG
    addi t1, zero, 1
    sw t1, 0(t0)

    ; Print greeting
    la a0, greeting
    jal ra, print_string

    ; Turn on all LEDs
    li t0, LED_REG
    addi t1, zero, 0x3f
    sw t1, 0(t0)

    ; Halt
halt:
    j halt

; Print null-terminated string at a0
print_string:
    li t2, UART_TX_DATA
    li t3, UART_TX_STATUS
print_loop:
    lbu t0, 0(a0)
    beq t0, zero, print_done
print_wait:
    lw t1, 0(t3)
    andi t1, t1, 1
    bne t1, zero, print_wait
    sb t0, 0(t2)
    addi a0, a0, 1
    j print_loop
print_done:
    ret

greeting:
    .asciz "Hello Zaheer!\r\n"
