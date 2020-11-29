# The Kora 16-bit Processor Project
The Kora processor is a new processor based on the Neva processor, but extremely expanded and better in every way.
The processor has a classic CISC instruction which is inspired by x86, 68000, ARM and RISC-V instruction sets.

Made by [Bastiaan van der Plaat](https://bastiaan.ml/)

<br/>

## Two different targets
What is new is that I want to run the processor on two different platforms, namely:

- Web Simulator version like [neva-processor.ml](https://neva-processor.ml/)
   - Web (JavaScript) Kora Assembler
- Altera Cyclone II FPGA dev board version
   - Modern (C) Kora Assembler
   - Native (Kora Assembly) Kora Assembler

<br/>

## Pages that inspired this project
- https://en.wikipedia.org/wiki/Intel_80386
- https://en.wikipedia.org/wiki/ARM_architecture
- https://en.wikipedia.org/wiki/Motorola_68000
- https://en.wikipedia.org/wiki/RISC-V
- https://en.wikipedia.org/wiki/X86_instruction_listings
- http://unixwiz.net/techtips/x86-jumps.html

<br/>

## Complete computer design
As I said, I want the kora processor to become a complete computer platform, which also includes peripheral equipment, eventually I want to keep this design for the complete computer:

![Kora computer design](docs/computer-design.png)

<br/>

## The new things compared to the Neva processor
- A new 16-bit simple design like the Neva processor
- A 24-bit external segmented address bus so much more memory access (2 ** 24 = 16 MB)
- But when all segments are zero you got just get a linair 16-bit address field to work
- A 16-bit data bus interface with the memory
- 6 more general purpose registers
- Taro video controller intergration
- New segement based memory model vs difficult banking model
- Variable instruction length encoding
- All instructions are conditional
- More flags and so conditions for instructions
- New instructions

<br/>

## Some things I like to include in the future
- A small instruction and data cache (like a Harvard design)
- A small RISC like instruction pipeline
- A hardware interupt system (for keyboard and vsync)
- A multiply and division instruction extention

<br/>

## Instruction encoding
Like the Neva processor, I have kept the instruction encoding quite simple, the mode value determines how the instruction is formed:

![Kora instruction encoding](docs/instruction-encoding.png)

<br/>

## Conditions

Unlike the Neva processor every instructions is conditional, this can benefit some assembly patterns:

| #  | Name | Meaning      | Condition                 |
| -- | ---- | ------------ | ------------------------- |
| 0  | \-   | Always       | true                      |
| 1  | \-n  | Never        | false                     |
|    |      |              |                           |
| 2  | \-c  | Carry        | carry                     |
| 3  | \-nc | Not carry    | !carry                    |
|    |      |              |                           |
| 4  | \-z  | Zero         | zero                      |
| 5  | \-nz | Not zero     | !zero                     |
|    |      |              |                           |
| 6  | \-s  | Sign         | sign                      |
| 7  | \-ns | Not sign     | !sign                     |
|    |      |              |                           |
| 8  | \-o  | Overflow     | overflow                  |
| 9  | \-no | Not overflow | !overflow                 |
|    |      |              |                           |
| 10 | \-a  | Above        | !carry && !zero           |
| 11 | \-na | Not above    | carry || zero             |
|    |      |              |                           |
| 12 | \-l  | Lesser       | sign != overflow          |
| 13 | \-nl | Not lesser   | sign == overflow          |
|    |      |              |                           |
| 14 | \-g  | Greater      | zero && sign == overflow  |
| 15 | \-ng | Not greater  | !zero || sign != overflow |

<br/>

## Registers

The Kora processor also has way more registers and all internal registers (the second half) are accessable for extra efficiency:

| #  | Name           | Meaning                                        |
| -- | -------------- | ---------------------------------------------- |
| 0  | a, r0          | General purpose A register                     |
| 1  | b, r1          | General purpose B register                     |
| 2  | c, r2          | General purpose C register                     |
| 3  | d, r3          | General purpose D register                     |
| 4  | e, r4          | General purpose E register                     |
| 5  | f, r5          | General purpose F register                     |
| 6  | g, r6          | General purpose G register                     |
| 7  | h, r7          | General purpose H register                     |
|    |                |                                                |
| 8  | ip, r8         | Instruction pointer register                   |
| 9  | rp, r9         | Return / previous instruction pointer register |
| 10 | sp, r10        | Stack pointer register                         |
| 11 | bp, r11        | Stack base pointer register                    |
| 12 | cs, r12        | Code segment register                          |
| 13 | ds, r13        | Data segment register                          |
| 14 | ss, r14        | Stacks segment register                        |
| 15 | fx, flags, r15 | Flags register                                 |

<br/>

## Flags

| #      | Name     | Meaning                             |
| ------ | -------- | ----------------------------------- |
| 0      | Carry    | Is set when a carry overflow occurs |
| 1      | Zero     | Is set when the result is zero      |
| 2      | Sign     | Is set when the sign bit is set     |
| 3      | Overflow | Is set when a overflow occurs       |
| 4 - 7  | Reseverd | \-                                  |
| 8      | Halted   | When set halteds the processor      |
| 9 - 15 | Reseverd | \-                                  |

<br/>

## Kora (re)starts jump address
When Kora (re)starts the instruction pointer register is set to `0x00000000` and the code segment register is set to `0xffffffff`
So the processor starts executing code at `0xffffffff00`

<br/>

## Instructions

| #       | Name          | Meaning                    | Operation                                                                                     |
| ------- | ------------- | -------------------------- | --------------------------------------------------------------------------------------------- |
| 0       | nop           | no operation               | \-                                                                                            |
|         |               |                            |                                                                                               |
| 1       | mov           | move                       | dest = data                                                                                   |
| 2       | lw            | load word (16-bit)         | dest = \[ds << 8 + data\]                                                                     |
| 3       | lb            | load signed byte (8-bit)   | dest = \[ds << 8 + data\] & 0xff (sign extended)                                              |
| 4       | lbu           | load unsigned byte (8-bit) | dest = \[ds << 8 + data\] & 0xff                                                              |
| 5       | sw            | store word (16-bit)        | \[ds << 8 + data\] = dest                                                                     |
| 6       | sb            | store byte (8-bit)         | \[ds << 8 + data\] = dest & 0xff                                                              |
|         |               |                            |                                                                                               |
| 7       | add           | add                        | dest += data                                                                                  |
| 8       | adc           | add with carry             | dest += data + carry                                                                          |
| 9       | sub           | subtract                   | dest -= data                                                                                  |
| 10      | sbb           | subtract with borrow       | dest -= data + borrow                                                                         |
| 11      | neg           | negate                     | dest = -data                                                                                  |
| 12      | cmp           | compare                    | dest - data (only set flags)                                                                  |
|         |               |                            |                                                                                               |
| 13      | and           | and                        | dest &= data                                                                                  |
| 14      | or            | or                         | dest |= data                                                                                  |
| 15      | xor           | xor                        | dest ^= data                                                                                  |
| 16      | not           | not                        | dest = ~data                                                                                  |
| 17      | shl           | logical shift lift         | dest <<= data & 15                                                                            |
| 18      | shr           | logical shift right        | dest >>= data & 15                                                                            |
| 19      | sar           | arithmetic shift right     | dest >>>= data & 15                                                                           |
|         |               |                            |                                                                                               |
| 20      | push          | push                       | \[ss << 8 + sp\] = data, sp -= 2                                                              |
| 21      | pop           | pop                        | sp += 2, dest = \[ss << 8 + sp\]                                                              |
|         |               |                            |                                                                                               |
| 22      | farjmp        | far jump                   | cs = dest, rp = ip, ip = data                                                                 |
| 23      | call          | call                       | \[ss << 8 + sp\] = ip, sp -= 2, rp = ip, ip =data                                             |
| 24      | call relative | call relative              | \[ss << 8 + sp\] = ip, sp -= 2, rp = ip, ip +=data                                            |
| 25      | farcall       | far call                   | \[ss << 8 + sp\] = cs, sp -= 2, \[ss << 8 + sp\] = ip, sp -= 2. cs = dest, rp = ip, ip = data |
| 26      | ret           | return                     | sp += 2+ data, rp = ip, ip = \[ss << 8 + sp\]                                                 |
| 27      | farret        | far return                 | sp += 2, rp = ip, ip = \[ss << 8 + sp\], sp += 2 + data, cs = \[ss << 8 + sp\]                |
|         |               |                            |                                                                                               |
| 28      | cpuid         | CPU information            | \* see CPUID section                                                                          |
|         |               |                            |                                                                                               |
| 29 - 63 | Reserved      |                            |                                                                                               |

<br/>

## CPUID instruction
This instruction is used to fetch information about the processor and it will set these registers:

```
b = 0x5634 ; Processor Manufacter id
c = 0xd347 ; Processor id
d = 0x01 00; Processor version first byte '.' last byte
e = 0x0000 ; Procesoor Manufacter Date Low Unix Timestamp
f = 0x0000 ; Procesoor Manufacter Date High Unix Timestamp
g = 0b00000000 00000001 ; Processor features bit list
   ; 0 = Multiply / Division extention
   ; 1 = Software / hardware Interupt extention
   ; 8 = Taro video generator chip
   ; 9 = Kiki PS/2 keyboard interface chip
   ; 10 = SD card storage device?? (need I2C, SPI)
   ; Etc...
```
