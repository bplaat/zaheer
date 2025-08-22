/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <stdint.h>

#define TARO_VIDEO_MEM_SIZE 0x6000
#define TARO_SCREEN_WIDTH_PX 640
#define TARO_SCREEN_HEIGHT_PX 480
#define TARO_SCREEN_WIDTH (TARO_SCREEN_WIDTH_PX / 8)
#define TARO_SCREEN_HEIGHT (TARO_SCREEN_HEIGHT_PX / 8)

typedef struct {
    uint8_t *video_mem;
    uint32_t addr;
    uint16_t data;
    uint16_t text_ptr;
    uint16_t font_ptr;
} Taro;

Taro *taro_new(void);

uint32_t taro_read(void *priv, uint32_t offset);

void taro_write(void *priv, uint32_t offset, uint32_t val, uint8_t wmask);

void taro_framebuffer_draw(Taro *taro, uint8_t *framebuffer);
