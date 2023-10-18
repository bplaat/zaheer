# Taro GPU
- 1 MiB VRAM
- 16-bit color in R5G6B5 format
- 640x480 DVI/HDMI output
- FIFO buffer with commands

## Commands
```c
struct cmd_done {
    uint8_t cmd; // 0
};

struct cmd_set_framebuffer {
    uint8_t cmd; // 1
    uint32_t addr;
    uint16_t stride;
};

struct cmd_set_clip {
    uint8_t cmd; // 2
    uint16_t top;
    uint16_t left;
    uint16_t right;
    uint16_t bottom;
};

struct cmd_clear {
    uint8_t cmd; // 3
    uint8_t r : 5;
    uint8_t g : 6;
    uint8_t b : 5;
};

struct cmd_triangle {
    uint8_t cmd; // 4

    uint16_t v0x;
    uint16_t v0y;
    uint8_t v0r : 5;
    uint8_t v0g : 6;
    uint8_t v0b : 5;

    uint16_t v1x;
    uint16_t v1y;
    uint8_t v1r : 5;
    uint8_t v1g : 6;
    uint8_t v1b : 5;

    uint16_t v2x;
    uint16_t v2y;
    uint8_t v2r : 5;
    uint8_t v2g : 6;
    uint8_t v2b : 5;
};

struct cmd_triangle_textured {
    uint8_t cmd; // 5
    uint32_t texture_addr;
    uint16_t texture_stride;

    uint16_t v0x;
    uint16_t v0y;
    uint8_t v0r : 5;
    uint8_t v0g : 6;
    uint8_t v0b : 5;
    uint8_t v0u;
    uint8_t v0v;

    uint16_t v1x;
    uint16_t v1y;
    uint8_t v1r : 5;
    uint8_t v1g : 6;
    uint8_t v1b : 5;
    uint8_t v1u;
    uint8_t v1v;

    uint16_t v2x;
    uint16_t v2y;
    uint8_t v2r : 5;
    uint8_t v2g : 6;
    uint8_t v2b : 5;
    uint8_t v2u;
    uint8_t v2v;
};
```
