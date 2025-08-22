/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdint.h>

typedef struct Device {
    void *priv;
    uint32_t start_addr;
    uint32_t size;
    uint32_t (*read)(void *priv, uint32_t offset);
    void (*write)(void *priv, uint32_t offset, uint32_t val, uint8_t wmask);
} Device;

typedef struct {
    Device *devices;
    uint32_t device_count;
    uint32_t capacity;
} Bus;

void bus_init(Bus *bus);

void bus_add_device(Bus *bus, void *priv, uint32_t start_addr, uint32_t size, uint32_t (*read)(void *, uint32_t),
                    void (*write)(void *, uint32_t, uint32_t, uint8_t));

uint32_t bus_read(Bus *bus, uint32_t addr);

void bus_write(Bus *bus, uint32_t addr, uint32_t val, uint8_t wmask);
