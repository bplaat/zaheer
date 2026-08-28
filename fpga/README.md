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

| Canonical address range | Size | Access | Component |
| --- | ---: | --- | --- |
| `0x00000000` - `0x00000FFF` | 4 KiB | Read-only | Boot ROM, 1,024 x 32 bits |
| `0x20000000` - `0x20000FFF` | 4 KiB | Read/write | Main RAM, 1,024 x 32 bits |
| `0x40000000` | 4 bytes | Write | UART TX data in bits 7:0 |
| `0x40000004` | 4 bytes | Read | UART TX status; bit 0 is busy |
| `0x40000008` | 4 bytes | Read | UART RX status; bits 0-2 are ready, overrun, and framing error |
| `0x4000000C` | 4 bytes | Read | UART RX data in bits 7:0; reading clears RX status |
| `0x60000000` | 4 bytes | Read/write | Six-bit LED register; board LEDs are active-low |
| `0x80000000` - `0x8000257F` | 9,600 bytes | Read/write | Taro text video RAM |

ROM, RAM, UART, and LED selection only decodes address bits 31:28. Their small
contents or registers therefore repeat throughout their respective 256 MiB
regions (`0x0...`, `0x2...`, `0x4...`, and `0x6...`). Software should use the
canonical addresses above. Video RAM is fully range-checked. Unmapped reads
return zero and unmapped writes are ignored.

Each video cell is 16 bits: bits 7:0 select one of 256 glyphs and bits 15:8 hold
the color attribute. The low attribute nibble is the foreground color and the
high nibble is the background color. Two adjacent cells are packed into each
32-bit CPU word, giving 2,400 words for 80 x 60 cells.

## RAM allocation

The GW1NR-9C has 26 BSRAM blocks of 18 Kbit each, or 468 Kbit in total. The
following table shows the expected block packing from the inferred memory
dimensions. The final count is controlled by Yosys and should be confirmed in
the synthesis and nextpnr reports after memory logic changes.

| Memory | Logical organization | Payload | Expected BSRAM blocks | Reason for the split |
| --- | ---: | ---: | ---: | --- |
| Boot ROM | 1,024 x 32 | 4,096 bytes | 2 | Initialized from `target/boot.mem` |
| Main RAM | 4 x 1,024 x 8 | 4,096 bytes | 4 | One byte-wide bank per write strobe |
| CPU registers | 32 x 32 | 128 bytes | 2 | Replication provides two reads plus one write |
| Even text cells | 2,400 x 16 | 4,800 bytes | 3 | Dual-clock CPU/display access |
| Odd text cells | 2,400 x 16 | 4,800 bytes | 3 | Dual-clock CPU/display access |
| Font ROM | 2,048 x 8 | 2,048 bytes | 1 | Initialized from `target/taro_font.mem` |
| **Total** | | **19,968 bytes** | **about 15 of 26** | **About 58% of the BSRAM blocks** |

The even and odd text memories are separate so the CPU can read or write a full
32-bit pair of cells while the display reads one cell on its pixel clock. Main
RAM is split into four byte banks so `SB`, `SH`, and `SW` stores can use the four
CPU write strobes without a read-modify-write cycle.

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
