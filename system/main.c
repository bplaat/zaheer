/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

// this bootload read from sdcard fat32 kernal exe
// file i/o
// uart i/o
// shell
// program load
// program sharding
// ipc

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// MARK: Stdlib
int __mulsi3(int a, int b) {
    int result = 0;
    while (b) {
        if (b & 1) result += a;
        a <<= 1;
        b >>= 1;
    }
    return result;
}

char *strcpy(char *dest, const char *src) {
    char *d = dest;
    while ((*d++ = *src++));
    return dest;
}

void *memset(void *s, int c, size_t n) {
    unsigned char *p = s;
    for (size_t i = 0; i < n; i++) p[i] = (unsigned char)c;
    return s;
}

void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = dest;
    const unsigned char *s = src;
    for (size_t i = 0; i < n; i++) d[i] = s[i];
    return dest;
}

// MARK: UART
#define UART_TX_DATA ((volatile uint8_t *)0x00800000)

void print_char(char c) { *UART_TX_DATA = c; }

void print(char *str) {
    while (*str) print_char(*str++);
}

void println(char *str) {
    print(str);
    print_char('\r');
    print_char('\n');
}

// MARK: Taro
#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 60
#define TARO_ADDR ((volatile uint16_t *)0x00800100)
#define TARO_DATA ((volatile uint16_t *)0x00800104)
#define TARO_TEXT_PTR ((volatile uint16_t *)0x00800108)
#define TARO_FONT_PTR ((volatile uint16_t *)0x0080010C)

typedef struct Window {
    char title[16];
    uint8_t id;
    uint8_t x;
    uint8_t y;
    uint8_t width;
    uint8_t height;
    uint8_t background_color;
    bool is_decorated;
    bool is_listed;
    bool is_focusable;
    void (*event_func)(struct Window *w);
} Window;

Window windows[8] = {0};
int8_t windows_size = 0;

int8_t window_drag_id = -1;
uint8_t window_drag_x = 0;

Window *window_new(char *title, uint16_t x, uint16_t y, uint16_t width, uint16_t height) {
    if (windows_size >= sizeof(windows) / sizeof(windows[0])) {
        return NULL;
    }
    uint8_t window_id = windows_size++;
    Window *w = &windows[window_id];
    strcpy(w->title, title);
    w->id = window_id;
    w->x = x;
    w->y = y;
    w->width = width;
    w->height = height;
    w->background_color = 0xf;
    w->is_decorated = true;
    w->is_listed = true;
    w->is_focusable = true;
    return w;
}

uint16_t text_ptr = 256 * 8;

void setpixel(int x, int y, char c, int color) {
    if (x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT) {
        *TARO_ADDR = text_ptr + (y * 80 + x) * 2;
        *TARO_DATA = (color << 8) | c;
    }
}

void window_text_draw(Window *w, int x, int y, char *text, size_t size) {
    int tx = w->x + x;
    int ty = w->y + y;
    for (size_t i = 0; i < size; i++) setpixel(tx++, ty, text[i], 0xf0);
}

// MARK: PS/2 Mouse
#define PS2_MOUSE_DATA_PTR ((volatile uint16_t *)0x00800200)
#define PS2_MOUSE_STATUS_PTR ((volatile uint16_t *)0x00800204)

int mouse_x = SCREEN_WIDTH * 8 / 2;
int mouse_y = SCREEN_HEIGHT * 8 / 2;
bool mouse_down = false;

void read_ps2_mouse() {
    if (*PS2_MOUSE_STATUS_PTR & 1) {  // Data available
        uint8_t packet[3];
        for (int i = 0; i < 3; i++) {
            packet[i] = *PS2_MOUSE_DATA_PTR & 0xFF;
        }
        // Parse packet
        int dx = (int8_t)packet[1];
        int dy = (int8_t)packet[2];
        mouse_x += dx;
        mouse_y -= dy;  // PS/2 Y is negative up
        if (mouse_x < 0) mouse_x = 0;
        if (mouse_x > 640) mouse_x = 640 - 1;
        if (mouse_y < 0) mouse_y = 0;
        if (mouse_y > 480) mouse_y = 480 - 1;

        // Parse mouse button (bit 0 of packet[0])
        mouse_down = (packet[0] & 1) != 0;
    }
}

uint8_t cursor[] = {0xC0, 0xA0, 0x90, 0x88, 0x84, 0x98, 0xA0, 0xC0};

// MARK: Main
void window3_event(Window *w) {
    for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
            setpixel(w->x + x + 1, w->y + y + 1, x + y * 16, 0xf0);
        }
    }

    // Draw all colors in a 2-row grid below the window content
    for (int color = 0; color < 16; color++) {
        for (int y = 0; y < 2; y++) {
            setpixel(w->x + color + 1, w->y + 18 + y, ' ', color << 4);
        }
    }
}

void boot_main(void) {
    println("Mako is booting...");

    // Update cursor character
    *TARO_ADDR = 0xff * 8;
    for (int i = 0; i < 8; i += 2) {
        uint16_t val = ((uint16_t)cursor[i + 1] << 8) | cursor[i];
        *TARO_DATA = val;
    }

    // Create windows
    Window *desktop = window_new("Desktop", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    desktop->is_decorated = false;
    desktop->is_focusable = false;
    desktop->background_color = 0x1;

    Window *system_bar = window_new("System Bar", 0, 0, SCREEN_WIDTH, 1);
    system_bar->is_decorated = false;
    system_bar->is_focusable = false;
    Window *task_bar = window_new("Task Bar", 0, SCREEN_HEIGHT - 1, SCREEN_WIDTH, 1);
    task_bar->is_decorated = false;
    task_bar->is_focusable = false;

    Window *window1 = window_new("Window 1", 10, 10, 20, 15);
    Window *window2 = window_new("Window 2", 20, 20, 25, 20);

    Window *window3 = window_new("Character Map", 5, 30, 22, 22);
    window3->event_func = window3_event;

    Window *window4 = window_new("Window 4", 50, 15, 10, 10);

    for (;;) {
        // Read mouse
        read_ps2_mouse();

        // Handle window dragging
        int mx = mouse_x / 8;
        int my = mouse_y / 8;
        if (mouse_down) {
            if (window_drag_id == -1) {
                for (int i = windows_size - 1; i >= 0; i--) {
                    Window *w = &windows[i];
                    if (!w->is_focusable) continue;
                    int left = w->x - 1;
                    int right = w->x + w->width + 1;
                    int top = w->y - 1;
                    int bottom = w->y + w->height + 1;

                    // Start window drag
                    if (w->is_decorated && my == top && mx >= left && mx < right) {
                        window_drag_id = w->id;
                        window_drag_x = mx - w->x;
                    }

                    // Focus window
                    if (my >= top && my < bottom && mx >= left && mx < right) {
                        Window tmp = windows[i];
                        for (int j = i; j < windows_size - 1; j++) {
                            windows[j] = windows[j + 1];
                        }
                        windows[windows_size - 1] = tmp;
                        break;
                    }
                }
            } else {
                // Drag window
                for (int i = 0; i < windows_size; i++) {
                    Window *w = &windows[i];
                    if (w->id == window_drag_id) {
                        int new_x = mx - window_drag_x;
                        int new_y = my + 1;
                        if (new_x < 0) new_x = 0;
                        if (new_x > SCREEN_WIDTH) new_x = SCREEN_WIDTH - w->width;
                        if (new_y < 0) new_y = 0;
                        if (new_y > SCREEN_HEIGHT) new_y = SCREEN_HEIGHT - w->height;
                        w->x = new_x;
                        w->y = new_y;
                    }
                }
            }
        } else {
            window_drag_id = -1;
        }

        // Swap text ptr
        if (text_ptr == 256 * 8) {
            text_ptr = 256 * 8 + SCREEN_WIDTH * SCREEN_HEIGHT * 2;
        } else {
            text_ptr = 256 * 8;
        }

        // Draw window decorations
        for (int i = 0; i < windows_size; i++) {
            Window *w = &windows[i];

            if (w->is_decorated) {
                bool is_focus = i == windows_size - 1;
                int border = ((is_focus ? 0x0 : 0x7 << 4) | (is_focus ? 0xf : 0x0));

                // Draw borders
                setpixel(w->x - 1, w->y - 1, 0xC9, border);
                setpixel(w->x + w->width, w->y - 1, 0xBB, border);
                setpixel(w->x - 1, w->y + w->height, 0xC8, border);
                setpixel(w->x + w->width, w->y + w->height, 0xBC, border);
                for (int x = w->x; x < w->x + w->width; x++) {
                    setpixel(x, w->y - 1, 0xCD, border);
                    setpixel(x, w->y + w->height, 0xCD, border);
                }
                for (int y = w->y; y < w->y + w->height; y++) {
                    setpixel(w->x - 1, y, 0xBA, border);
                    setpixel(w->x + w->width, y, 0xBA, border);
                }

                // Draw contents
                for (int x = 0; w->title[x] != '\0'; x++) {
                    setpixel(w->x + x, w->y - 1, w->title[x], border);
                }
                setpixel(w->x + w->width - 3, w->y - 1, 0x1f, border);
                setpixel(w->x + w->width - 2, w->y - 1, 0x1e, border);
                setpixel(w->x + w->width - 1, w->y - 1, 'X', border);
            }

            // Draw background
            for (int y = 0; y < w->height; y++) {
                for (int x = 0; x < w->width; x++) {
                    setpixel(w->x + x, w->y + y, ' ', w->background_color << 4);
                }
            }

            // Draw contents
            if (w->event_func) {
                w->event_func(w);
            }
        }

        // Draw mouse
        if (mx >= 0 && mx < SCREEN_WIDTH && my >= 0 && my < SCREEN_HEIGHT) {
            *TARO_ADDR = text_ptr + (my * SCREEN_WIDTH + mx) * 2;
            uint8_t bg_color = *TARO_DATA >> 12;
            *TARO_DATA = bg_color << 12 | (bg_color < 0x7 ? 0xf : 0x0) << 8 | 0xff;
        }

        // Swap buffer
        *TARO_TEXT_PTR = text_ptr;
    }
}
