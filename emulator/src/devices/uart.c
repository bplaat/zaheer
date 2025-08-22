/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#include "uart.h"

#include <stdio.h>
#include <stdlib.h>

// MARK: UART TX
UartTx *uart_tx_new(void) {
    UartTx *uart = malloc(sizeof(UartTx));
    uart->data = 0;
    uart->busy = false;
    return uart;
}

uint32_t uart_tx_read(void *priv, uint32_t offset) {
    UartTx *uart = (UartTx *)priv;
    if (offset == 0) {  // Data register
        return uart->data;
    }
    if (offset == 4) {  // Status register
        return uart->busy ? 1 : 0;
    }
    fprintf(stderr, "UART TX read invalid offset: 0x%08x\n", offset);
    exit(1);
    return 0;
}

void uart_tx_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask) {
    UartTx *uart = (UartTx *)priv;
    if (offset == 0) {  // Data register
        if (wmask & 1) {
            uart->data = val & 0xFF;
            uart->busy = true;
            // Simulate transmission complete immediately
            putchar(uart->data);
            fflush(stdout);
            uart->busy = false;
        }
    } else {
        fprintf(stderr, "UART TX write invalid offset: 0x%08x\n", offset);
        exit(1);
    }
}
