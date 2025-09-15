/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

// MARK: UART TX
typedef struct {
    uint8_t data;
    bool busy;
} UartTx;

UartTx *uart_tx_new(void);

uint32_t uart_tx_read(void *priv, uint32_t offset);

void uart_tx_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask);
