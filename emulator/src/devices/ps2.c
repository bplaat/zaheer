/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#include "ps2.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// MARK: PS/2 Mouse
Ps2Mouse *ps2_mouse_new(void) {
    Ps2Mouse *mouse = malloc(sizeof(Ps2Mouse));
    mouse->head = 0;
    mouse->tail = 0;
    memset(mouse->buffer, 0, sizeof(mouse->buffer));
    return mouse;
}

uint32_t ps2_mouse_read(void *priv, uint32_t offset) {
    Ps2Mouse *mouse = (Ps2Mouse *)priv;
    switch (offset) {
        case 0:  // Data register
            if (mouse->tail != mouse->head) {
                uint8_t val = mouse->buffer[mouse->tail];
                mouse->tail = (mouse->tail + 1) % 4;
                return val;
            } else {
                return 0;  // No data
            }
        case 4:  // Status register
            return (mouse->tail != mouse->head) ? 1 : 0;
        default:
            fprintf(stderr, "PS/2 Mouse read invalid offset: 0x%08x\n", offset);
            exit(1);
    }
    return 0;
}

void ps2_mouse_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask) {
    Ps2Mouse *mouse = (Ps2Mouse *)priv;
    // Only allow writing if buffer is not full
    if (offset == 0 && wmask & 1) {
        int next_head = (mouse->head + 1) % 4;
        if (next_head != mouse->tail) {
            mouse->buffer[mouse->head] = val & 0xFF;
            mouse->head = next_head;
        }
        // else: buffer full, drop byte
    }
}

void ps2_mouse_process_event(Ps2Mouse *mouse, SDL_Event *event) {
    if (event->type == SDL_MOUSEMOTION) {
        int dx = event->motion.xrel;
        int dy = event->motion.yrel;
        uint8_t mouse_packet[3];
        mouse_packet[0] = 0x08 | (event->motion.state & 0x07);  // Always 1 in bit 3, buttons in bits 0-2
        mouse_packet[1] = (uint8_t)dx;
        mouse_packet[2] = (uint8_t)-dy;
        for (int i = 0; i < 3; i++) {
            ps2_mouse_write(mouse, 0, mouse_packet[i], 1);
        }
    }

    if (event->type == SDL_MOUSEBUTTONDOWN || event->type == SDL_MOUSEBUTTONUP) {
        uint8_t buttons = 0;
        if (event->button.button == SDL_BUTTON_LEFT) buttons |= 1;
        if (event->button.button == SDL_BUTTON_RIGHT) buttons |= 2;
        if (event->button.button == SDL_BUTTON_MIDDLE) buttons |= 4;
        uint8_t mouse_packet[3];
        mouse_packet[0] = 0x08 | buttons;
        mouse_packet[1] = 0;
        mouse_packet[2] = 0;
        for (int i = 0; i < 3; i++) {
            ps2_mouse_write(mouse, 0, mouse_packet[i], 1);
        }
    }
}
