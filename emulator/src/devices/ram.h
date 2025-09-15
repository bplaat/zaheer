/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdint.h>

typedef struct {
    uint8_t *mem;
    uint32_t size;
} Ram;

Ram *ram_new(uint32_t size);

uint32_t ram_read(void *priv, uint32_t offset);

void ram_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask);
