# The Taro video generator
The Taro video generator is a simple video signal generator

## Features
- 10K video RAM + 2K character RAM
- 640x480 color VGA output
- Text modes with 2 or 16 colors
- Which uses 8x8 pixels character font
- Bitmaps modes with 2 or 16 colors
- Vertical smooth scrolling via a video RAM offset
- Future: Vertical sync interupt

## Memory interface with the Kora processor
The video generator has it own RAM so the processor has to write to special registers in RAM to edit that in a controlled manner:

```
0x008000: Video mode
0x008001: Monochrome background color (4 - 7), Monochrome foreground color (0 - 3)
0x008002 - 0x008003: Address
0x008004 - 0x008005: Data Read/Write
0x008006 - 0x008007: Address auto increment
0x008008 - 0x008009: Video data offset
0x00800a - 0x00800f: Reserved
```

## Video modes
The mode is set by settings multiple bits, you can only enable one output resolutions at the same time!
```
0 = text or bitmap
1 = 2 colors or 16 colors
2 = 20x15 text or 160x120 bitmap 4x scaled
3 = 40x30 text or 320x240 bitmap 2x scaled
4 = 80x60 text or 640x480 bitmap 1x scaled
5 - 7 = Reserved
```

## Colors
The Taro video generator uses the VGA/CGA colors:

- https://en.wikipedia.org/wiki/VGA_text_mode
- https://en.wikipedia.org/wiki/Color_Graphics_Adapter#Color_palette

```
 0 = black #000000
 1 = blue #0000AA
 2 = green #00AA00
 3 = cyan #00AAAA
 4 = red #AA0000
 5 = magenta #AA00AA
 6 = brown #AA5500
 7 = light gray #AAAAAA
 8 = dark gray #555555
 9 = light blue #5555FF
10 = light green #55FF55
11 = light cyan #55FFFF
12 = light red #FF5555
13 = light magenta #FF55FF
14 = yellow #FFFF55
15 = white #FFFFFF
```

## Video memory layout
The Taro video generator has two RAM chips which are mapped to different areas.

```
0x0000:0x257f video data 10k (80 * 60 * 2 or 320 * 240 / 8 = 9600 -> 10240)
```

```
0x2800:0x2fff character font data 2k (256 * 8 = 2048)
```

When the video data read pointer overflows it wraps around to 0x0000 and not the the character data!

## Video data encoding
The monochrome text modes are encoded like:

```
  8 bit   |   8 bit   | Etc...
character | character | Etc...
```

The colered text modes are encoded like:

```
  8 bit   |       4 bit           4 bit       |   8 bit   |       4 bit           4 bit       | Etc...
character | background color foreground color | character | background color foreground color | Etc...
```

The monochrome bitmaps are encoded like:

```
1 bit 1 bit 1 bit 1 bit 1 bit 1 bit 1 bit 1 bit | 1 bit 1 bit 1 bit 1 bit 1 bit 1 bit 1 bit 1 bit | Etc...
pixel pixel pixel pixel pixel pixel pixel pixel | pixel pixel pixel pixel pixel pixel pixel pixel | Etc...
```

The colored bitmaps are encoded like:

```
   4 bit       4 bit    |    4 bit       4 bit    | Etc...
pixel color pixel color | pixel color pixel color | Etc...
```

## Character encoding / font
The Taro video generator uses standard the Codepage-437 as the character encoding and font.

https://en.wikipedia.org/wiki/Code_page_437#Character_set

## Sample programs
```
; Fake addresses for know
TARO_MODE equ 0x8000
TARO_COLOR equ 0x8001
TARO_ADDRESS equ 0x8002
TARO_DATA equ 0x8004
TARO_INCREMENT equ 0x8006
TARO_OFFSET equ 0x8008

start:
    ; Set data segment to I/O area
    mov ds, 0x0000

    ; Set mode to 80x60 colored text
    mov t0, 0b10010
    mov byte [TARO_MODE], t0

    ; Set offset to 0
    mov t0, 0x0000
    mov [TARO_OFFSET], t0

    ; Set address auto increment to 2
    mov t0, 2
    mov [TARO_OFFSET], t0

    ; Set address to 0
    mov t0, 0x0000
    mov [TARO_ADDRESS], t0

    ; Set address in unused register for smaller instructions
    mov t1, TARO_DATA

    ; Draw colored B to the screen
    mov t0, (0x1F << 8) + 'B'
    mov [t1], t0

    ; Draw colored A to the screen
    mov t0, (0x2F << 8) + 'A'
    mov [t1], t0

    ; Draw colored S to the screen
    mov t0, (0x3F << 8) + 'S'
    mov [t1], t0

    ; Draw colored T to the screen
    mov t0, (0x4F << 8) + 'T'
    mov [t1], t0

    ; Draw colored I to the screen
    mov t0, (0x5F << 8) + 'I'
    mov [t1], t0

    ; Draw colored A to the screen
    mov t0, (0x6F << 8) + 'A'
    mov [t1], t0

    ; Draw colored A to the screen
    mov t0, (0x7F << 8) + 'A'
    mov [t1], t0

    ; Draw colored N to the screen
    mov t0, (0x8F << 8) + 'N'
    mov [t1], t0

    halt
```
