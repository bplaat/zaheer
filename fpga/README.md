# FPGA design

Zaheer currently targets the Sipeed Tang Nano 9K, which contains a Gowin
GW1NR-9C FPGA. The design runs from the board's 27 MHz clock and contains a
small RV32I computer with UART, LEDs, and an 80x60 text-mode HDMI output.

## Components

- `top.v` connects the CPU to ROM, RAM, and the memory-mapped devices. It also
  generates power-on and push-button reset signals.
- `cpu.v` is a multi-cycle RV32I CPU. It has no CSRs or traps, treats
  `ECALL`, `EBREAK`, and `FENCE` as NOPs, and does not trap misaligned accesses.
- `uart/` provides a 115200 baud transmitter, receiver, and four-register UART.
- `taro/` provides an 80x60 text display, an 8x8 font, 640x480 timing, TMDS
  encoding, and HDMI serialization. Its PLL derives 126 MHz and 25.2 MHz clocks
  from the 27 MHz input.
- `tangnano9k.cst` assigns the board pins and `nextpnr_constraints.py` adds
  placement constraints used while building the bitstream.

## CPU memory map

The CPU uses byte addresses and little-endian 32-bit words.

| Canonical address range     |        Size | Access     | Component                                                      |
| --------------------------- | ----------: | ---------- | -------------------------------------------------------------- |
| `0x00000000` - `0x00000FFF` |       4 KiB | Read-only  | Boot ROM, 1,024 x 32 bits                                      |
| `0x20000000` - `0x20000FFF` |       4 KiB | Read/write | Main RAM, 1,024 x 32 bits                                      |
| `0x40000000`                |     4 bytes | Write      | UART TX data in bits 7:0                                       |
| `0x40000004`                |     4 bytes | Read       | UART TX status; bit 0 is busy                                  |
| `0x40000008`                |     4 bytes | Read       | UART RX status; bits 0-2 are ready, overrun, and framing error |
| `0x4000000C`                |     4 bytes | Read       | UART RX data in bits 7:0; reading clears RX status             |
| `0x60000000`                |     4 bytes | Read/write | Six-bit LED register; board LEDs are active-low                |
| `0x80000000` - `0x8000257F` | 9,600 bytes | Read/write | Taro text video RAM                                            |
| `0x80002580` - `0x80002D7F` | 2,048 bytes | Read/write | Taro 256-glyph font RAM                                        |

ROM, RAM, UART, and LED selection only decodes address bits 31:28. Their small
contents or registers therefore repeat throughout their respective 256 MiB
regions (`0x0...`, `0x2...`, `0x4...`, and `0x6...`). Software should use the
canonical addresses above. Video RAM is fully range-checked. Unmapped reads
return zero and unmapped writes are ignored.

Each video cell is 16 bits: bits 7:0 select one of 256 glyphs and bits 15:8 hold
the color attribute. The low attribute nibble is the foreground color and the
high nibble is the background color. Two adjacent cells are packed into each
32-bit CPU word, giving 2,400 words for 80 x 60 cells. Each font glyph contains
eight consecutive bytes, one for each 8-pixel row. Boot firmware copies the
font embedded in ROM to writable font RAM before clearing the screen.

## RAM allocation

The GW1NR-9C has 26 BSRAM blocks of 18 Kbit each, or 468 Kbit in total. The
raw capacity of each block is 2,304 bytes. Memory width, depth, byte-write
lanes, and extra read ports determine the number of complete blocks reserved;
unused space inside a reserved block cannot automatically be shared with an
unrelated memory.

The expected conceptual block allocation is shown below. Block numbers are
only labels for explaining the split; nextpnr chooses the physical BSRAM sites.

| Conceptual blocks | Memory            | Logical data | Raw block capacity | Unused or overhead | Packing reason                                 |
| ----------------- | ----------------- | -----------: | -----------------: | -----------------: | ---------------------------------------------- |
| 0-1               | Boot ROM          |  4,096 bytes |        4,608 bytes |          512 bytes | Two 1,024 x 16 halves form the 32-bit ROM      |
| 2-5               | Main RAM          |  4,096 bytes |        9,216 bytes |        5,120 bytes | One 1,024 x 8 block per CPU byte-write lane    |
| 6-7               | CPU registers     |    128 bytes |        4,608 bytes |        4,480 bytes | Two copies provide two reads plus one write    |
| 8-11              | Even text cells   |  4,800 bytes |        9,216 bytes |        4,416 bytes | Two 2,400 x 8 banks, each spanning two blocks  |
| 12-15             | Odd text cells    |  4,800 bytes |        9,216 bytes |        4,416 bytes | Two 2,400 x 8 banks, each spanning two blocks  |
| 16-19             | Font RAM          |  2,048 bytes |        9,216 bytes |        7,168 bytes | One 512 x 8 block per writable byte lane       |
| **20-25 free**    | Unallocated BSRAM |  **0 bytes** |   **13,824 bytes** |   **13,824 bytes** | **6 blocks remain available**                  |

This expected layout reserves about 77% of the BSRAM blocks, but only one third
of the device's 59,904-byte raw BSRAM capacity holds unique logical data. The
difference is caused mainly by the shallow byte-wide main/font banks, the
replicated CPU register file, partially filled text-memory blocks, and the
fixed width modes of an 18 Kbit block.

In short:

- 20 blocks (46,080 raw bytes) are expected to be reserved by the design.
- 19,968 bytes in those blocks are unique ROM or RAM contents.
- 26,112 bytes are unused packing space or register-file replication overhead.
- 6 complete blocks (13,824 raw bytes) remain free.

These are packing estimates from the inferred array shapes, not a synthesis
report. The final block count and mapping must be confirmed in the Yosys and
nextpnr reports after memory logic changes.

The even and odd text memories each use separate character and attribute byte
banks. This lets the CPU read or write a full 32-bit pair of cells while the
display reads one cell on its pixel clock, and matches the block RAM write
granularity. Main RAM is also split into four byte banks so `SB`, `SH`, and
`SW` stores can use the four CPU write strobes without a read-modify-write
cycle.

Other memory resources are currently unused by the CPU address map:

- The 17 Kbit shadow SRAM (SSRAM) is not explicitly instantiated.
- The embedded 64 Mbit PSRAM has no controller in this design.
- The 608 Kbit user flash and board SPI flash are not runtime CPU memory. The
  board flash may hold the FPGA bitstream when using `make flash`.

The board also provides 8,640 LUT4s, 6,480 flip-flops, two PLLs, and twenty
18 x 18 multipliers. Taro uses one PLL; exact LUT and flip-flop use depends on
the toolchain version and is reported by `make build`.

Board resource totals are listed in the
[Tang Nano 9K documentation](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K).
