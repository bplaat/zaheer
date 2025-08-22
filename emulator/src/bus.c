/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#include "bus.h"

#include <stdio.h>
#include <stdlib.h>

void bus_init(Bus *bus) {
    bus->devices = NULL;
    bus->device_count = 0;
    bus->capacity = 0;
}

void bus_add_device(Bus *bus, void *priv, uint32_t start_addr, uint32_t size, uint32_t (*read)(void *, uint32_t),
                    void (*write)(void *, uint32_t, uint32_t, uint8_t)) {
    if (bus->device_count >= bus->capacity) {
        bus->capacity = bus->capacity != 0 ? bus->capacity * 2 : 8;
        bus->devices = realloc(bus->devices, bus->capacity * sizeof(Device));
    }

    Device *dev = &bus->devices[bus->device_count++];
    dev->priv = priv;
    dev->start_addr = start_addr;
    dev->size = size;
    dev->read = read;
    dev->write = write;
}

uint32_t bus_read(Bus *bus, uint32_t addr) {
    addr &= ~0x3;
    for (uint32_t i = 0; i < bus->device_count; i++) {
        Device *dev = &bus->devices[i];
        if (addr >= dev->start_addr && addr < dev->start_addr + dev->size) {
            return dev->read(dev->priv, addr - dev->start_addr);
        }
    }
    fprintf(stderr, "Bus read error at address 0x%08x\n", addr);
    exit(1);
    return 0;
}

void bus_write(Bus *bus, uint32_t addr, uint32_t val, uint8_t wmask) {
    addr &= ~0x3;
    for (uint32_t i = 0; i < bus->device_count; i++) {
        Device *dev = &bus->devices[i];
        if (addr >= dev->start_addr && addr < dev->start_addr + dev->size) {
            dev->write(dev->priv, addr - dev->start_addr, val, wmask);
            return;
        }
    }
    fprintf(stderr, "Bus write error at address 0x%08x\n", addr);
    exit(1);
}
