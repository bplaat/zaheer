/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#define UART_TX_DATA ((volatile char *)0x01000000)

void print_char(char c) {
    *UART_TX_DATA = c;
}

void print(char *str) {
    while (*str)
       print_char(*str++);
}

void println(char *str) {
    print(str);
    print_char('\r');
    print_char('\n');
}

void boot_main(void) {
    for (;;) {
        print("Hello");
        println(" World");
    }
}
