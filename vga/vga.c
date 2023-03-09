/**
 * KORA VGA EXAMPLE, connections:
 *  - GPIO 16 ---> 68 ohm resistor  ---> VGA Hsync
 *  - GPIO 17 ---> 68 ohm resistor  ---> VGA Vsync
 *  - GPIO 18 ---> 330 ohm resistor ---> VGA Red
 *  - GPIO 19 ---> 330 ohm resistor ---> VGA Green
 *  - GPIO 20 ---> 330 ohm resistor ---> VGA Blue
 *  - GPIO 21 ---> 330 ohm resistor ---> VGA Bright
 *  - RP2040 GND ---> VGA GND
 */
#include <stdio.h>
#include <stdlib.h>

#include "hardware/dma.h"
#include "hardware/pio.h"
#include "hsync.pio.h"
#include "pico/stdlib.h"
#include "rgb.pio.h"
#include "vsync.pio.h"
#include "font.h"

// PIO counter init values
#define H_ACTIVE 655              // (active + frontporch - 1) - one cycle delay for mov
#define V_ACTIVE 479              // (active - 1)
#define RGB_ACTIVE (320 / 2 - 1)  // (horizontal active)/2 - 1

// Pins
#define HSYNC 16
#define VSYNC 17
#define RED_PIN 18
#define GREEN_PIN 19
#define BLUE_PIN 20
#define BRIGHT_PIN 21

// Ids
uint32_t hsync_id = 0;
uint32_t vsync_id = 1;
uint32_t rgb_id = 2;
uint32_t rgb_dma_id = 0;

// VRAM
uint8_t buffer1[(320 / 2) * 240] __attribute__((section("ram2_section")));
uint8_t buffer2[(320 / 2) * 240] __attribute__((section("ram3_section")));
uint8_t *vram = buffer1;
uint8_t *dma_ram = buffer2;

// Line addr DMA irq
bool use_buffer1 = false;
volatile int32_t line = 0;
void dma_line_done_handler() {
    dma_hw->ints0 = 1 << rgb_dma_id;
    dma_channel_set_read_addr(rgb_dma_id, &dma_ram[(320 >> 1) * (line >> 1)], true);
    if (line == 480 - 1) {
        line = 0;
    } else {
        line++;
    }
}

// Swap double buffers
void present() {
    if (use_buffer1) {
        use_buffer1 = false;
        vram = buffer2;
        dma_ram = buffer1;
    } else {
        use_buffer1 = true;
        vram = buffer1;
        dma_ram = buffer2;
    }
}

// Drawing functions
void setPixel(int32_t x, int32_t y, int32_t color) {
    int32_t index = (y * 320 + x) >> 1;
    if (x & 1) {
        vram[index] = (color << 4) | (vram[index] & 0x0f);
    } else {
        vram[index] = color | (vram[index] & 0xf0);
    }
}

void clearScreen(int32_t color) {
    for (int i = 0; i < (320 / 2) * 240; i++) {
        vram[i] = color | (color << 4);
    }
}

void fillRect(int32_t x, int32_t y, int32_t width, int32_t height, int32_t color) {
    for (int32_t ry = y; ry < y + height; ry++) {
        for (int32_t rx = x; rx < x + width; rx++) {
            int32_t index = (ry * 320 + rx) >> 1;
            if (rx & 1) {
                vram[index] = (color << 4) | (vram[index] & 0x0f);
            } else {
                vram[index] = color | (vram[index] & 0xf0);
            }
        }
    }
}

void drawString(int x, int y, char *str, int color) {
    char *c = str;
    while (*c) {
        for (int y2 = 0; y2 < 8; y2++) {
            int line = font[(*c << 3) | y2];
            for (int x2 = 0; x2 < 8; x2++) {
                if ((line >> (7 - x2)) & 1) {
                    int32_t index = ((y + y2) * 320 + (x + x2)) >> 1;
                    if ((x + x2) & 1) {
                        vram[index] = (color << 4) | (vram[index] & 0x0f);
                    } else {
                        vram[index] = color | (vram[index] & 0xf0);
                    }
                }
            }
        }
        x += 8;
        c++;
    }
}

// Draw loop
typedef struct Block {
    int16_t x;
    int16_t y;
    int16_t width;
    int16_t height;
    int16_t vx;
    int16_t vy;
    uint8_t color;
} Block;

Block blocks[] = {{0, 0, 50, 50, 1, 1, 0b0110},
                  {150 - 40, 150 - 60, 50, 30, -1, 1, 0b0011},
                  {300 - 40, 200 - 60, 40, 60, -1, -1, 0b0001}};
uint8_t background_color = 0xf;
int frames = 0;

void draw(void) {
    clearScreen(background_color);

    for (int32_t i = 0; i < sizeof(blocks) / sizeof(Block); i++) {
        Block *block = &blocks[i];
        fillRect(block->x, block->y, block->width, block->height, block->color);
        block->x += block->vx;
        block->y += block->vy;
        if (block->x < 0 || block->x + block->width >= 320 - 1) {
            block->vx = -block->vx;
        }
        if (block->y < 0 || block->y + block->height >= 240 - 1) {
            block->vy = -block->vy;
        }
    }

    drawString(2, 2, "Kora Computer", background_color ^ 0xf);
    drawString(2, 2 + 8, "320x240x16 colors", background_color ^ 0xf);
    drawString(2, 2 + 2 * 8, "Double buffered!", background_color ^ 0xf);

    for (int i = 0; i < 16; i++) {
        fillRect(i * 10 + 1, 240 - 10 - 1, 10, 10, i);
    }

    if (frames > rand() % 1500 + 500) {
        frames = 0;
        background_color = rand() & 0xf;
    }
    frames++;
    present();
}

// Main
void main(void) {
    stdio_init_all();

    // PIO's
    PIO pio = pio0;
    uint32_t hsync_offset = pio_add_program(pio, &hsync_program);
    uint32_t vsync_offset = pio_add_program(pio, &vsync_program);
    uint32_t rgb_offset = pio_add_program(pio, &rgb_program);
    hsync_program_init(pio, hsync_id, hsync_offset, HSYNC);
    vsync_program_init(pio, vsync_id, vsync_offset, VSYNC);
    rgb_program_init(pio, rgb_id, rgb_offset, RED_PIN);
    pio_sm_put_blocking(pio, hsync_id, H_ACTIVE);
    pio_sm_put_blocking(pio, vsync_id, V_ACTIVE);
    pio_sm_put_blocking(pio, rgb_id, RGB_ACTIVE);

    // DMA line copy
    dma_channel_config c0 = dma_channel_get_default_config(rgb_dma_id);
    channel_config_set_transfer_data_size(&c0, DMA_SIZE_8);
    channel_config_set_read_increment(&c0, true);
    channel_config_set_write_increment(&c0, false);
    channel_config_set_dreq(&c0, DREQ_PIO0_TX2);
    dma_channel_configure(rgb_dma_id, &c0, &pio->txf[rgb_id], NULL, 320 / 2, false);
    dma_channel_set_irq0_enabled(rgb_dma_id, true);
    irq_set_exclusive_handler(DMA_IRQ_0, dma_line_done_handler);
    irq_set_enabled(DMA_IRQ_0, true);

    // Start PIO's and DMA
    pio_enable_sm_mask_in_sync(pio, ((1 << hsync_id) | (1 << vsync_id) | (1 << rgb_id)));
    dma_start_channel_mask((1 << rgb_dma_id));

    // Draw loop
    for (;;) {
        draw();
    }
}
