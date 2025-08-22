/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

// ps/2 keyboard mouse
// uart rx
// sdcard support

#include <SDL2/SDL.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "bus.h"
#include "devices/cpu.h"
#include "devices/ps2.h"
#include "devices/ram.h"
#include "devices/taro.h"
#include "devices/uart.h"

int main(void) {
    // Create bus
    Bus bus;
    bus_init(&bus);

    // Add CPU
    Cpu cpu;
    cpu_init(&cpu, &bus);

    // Add RAM
    Ram *ram = ram_new(0x2000);
    bus_add_device(&bus, ram, 0x00000000, 0x2000, ram_read, ram_write);

    // Load program into ram
    FILE *boot_file = fopen("../system/boot.bin", "rb");
    if (!boot_file) {
        fprintf(stderr, "Failed to open boot.bin\n");
        return EXIT_FAILURE;
    }
    fseek(boot_file, 0, SEEK_END);
    size_t program_size = ftell(boot_file);
    fseek(boot_file, 0, SEEK_SET);
    fread(ram->mem, 1, program_size, boot_file);
    fclose(boot_file);

    // Add I/O devices
    UartTx *uart = uart_tx_new();
    bus_add_device(&bus, uart, 0x00800000, 0x08, uart_tx_read, uart_tx_write);

    Taro *taro = taro_new();
    bus_add_device(&bus, taro, 0x00800100, 0x0f, taro_read, taro_write);

    Ps2Mouse *mouse = ps2_mouse_new();
    bus_add_device(&bus, mouse, 0x00800200, 0x08, ps2_mouse_read, ps2_mouse_write);

    // Create window
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    char *window_title = "Zaheer Emulator";
    SDL_Window *window = SDL_CreateWindow(window_title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                          TARO_SCREEN_WIDTH_PX * 2, TARO_SCREEN_HEIGHT_PX * 2, SDL_WINDOW_RESIZABLE);

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_RenderSetLogicalSize(renderer, TARO_SCREEN_WIDTH_PX, TARO_SCREEN_HEIGHT_PX);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGB24, SDL_TEXTUREACCESS_STREAMING,
                                             TARO_SCREEN_WIDTH_PX, TARO_SCREEN_HEIGHT_PX);
    uint8_t *framebuffer = (uint8_t *)malloc(TARO_SCREEN_WIDTH_PX * TARO_SCREEN_HEIGHT_PX * 3);

    // Main loop
    SDL_Event event;
    bool running = true;
    bool mouse_locked = false;
    while (running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) running = false;

            if (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE) {
                if (mouse_locked) {
                    mouse_locked = false;
                    SDL_SetWindowTitle(window, window_title);
                    SDL_ShowCursor(SDL_ENABLE);
                    SDL_SetRelativeMouseMode(SDL_FALSE);
                }
            }

            if (event.type == SDL_MOUSEBUTTONDOWN || event.type == SDL_MOUSEBUTTONUP) {
                if (!mouse_locked) {
                    mouse_locked = true;
                    char new_window_title[255];
                    strcpy(new_window_title, window_title);
                    strcat(new_window_title, " (Unlock mouse press ESC)");
                    SDL_SetWindowTitle(window, new_window_title);
                    SDL_ShowCursor(SDL_DISABLE);
                    SDL_SetRelativeMouseMode(SDL_TRUE);
                }
            }

            if (mouse_locked) ps2_mouse_process_event(mouse, &event);
        }

        taro_framebuffer_draw(taro, framebuffer);

        // Run cpu cycles
        for (int i = 0; i < 1e6; i++) cpu_step(&cpu);

        // Update and render texture
        SDL_UpdateTexture(texture, NULL, framebuffer, TARO_SCREEN_WIDTH_PX * 3);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return EXIT_SUCCESS;
}
