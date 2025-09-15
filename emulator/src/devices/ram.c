/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#include "ram.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Ram *ram_new(uint32_t size) {
    Ram *ram = malloc(sizeof(Ram));
    ram->size = size;
    ram->mem = calloc(size, 1);
    return ram;
}

uint32_t ram_read(void *priv, uint32_t offset) {
    Ram *ram = (Ram *)priv;
    if (offset + 4 > ram->size) {
        fprintf(stderr, "RAM read out of bounds: offset 0x%08x\n", offset);
        exit(1);
    }
    uint32_t val = 0;
    memcpy(&val, ram->mem + offset, 4);
    return val;
}

void ram_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask) {
    Ram *ram = (Ram *)priv;
    if (offset + 4 > ram->size) {
        fprintf(stderr, "RAM write out of bounds: offset 0x%08x\n", offset);
        exit(1);
    }
    uint8_t *dest = ram->mem + offset;
    for (int i = 0; i < 4; i++) {
        if (wmask & (1 << i)) {
            dest[i] = (val >> (i * 8)) & 0xFF;
        }
    }
}
