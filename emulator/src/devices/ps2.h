/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#include <SDL2/SDL.h>
#include <stdint.h>

// MARK: PS/2 Mouse
typedef struct {
    uint8_t buffer[4];
    int head;
    int tail;
} Ps2Mouse;

Ps2Mouse *ps2_mouse_new(void);

uint32_t ps2_mouse_read(void *priv, uint32_t offset);

void ps2_mouse_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask);

void ps2_mouse_process_event(Ps2Mouse *mouse, SDL_Event *event);
