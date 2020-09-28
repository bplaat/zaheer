# The Kora 32-bit Processor Project
The Kora processor is a new processor based on the Neva processor, but extremely expanded and better in every way.
The processor has a classic CISC instruction which is inspired by x86, 68000 and ARM instruction sets.

Made by [Bastiaan van der Plaat](https://bastiaan.ml/)

## Subprojects:
What is new is that I want to run the processor on different platforms, namely:

- Web Simulator version like [neva-processor.ml](https://neva-processor.ml/)
   - Web (JavaScript) Kora Assembler
- NodeMCU (ESP8266) Microcontroller Simulator version
   - Modern (C) Kora Assembler
- Altera Cyclone II FPGA dev board version
   - Native (Kora Assembly) Kora Assembler

## Pages that inspired this project
- https://en.wikipedia.org/wiki/Intel_80386
- https://en.wikipedia.org/wiki/ARM_architecture
- https://en.wikipedia.org/wiki/Motorola_68000
- https://en.wikipedia.org/wiki/X86_instruction_listings
- http://unixwiz.net/techtips/x86-jumps.html

## The new things compared to the Neva processor:
- A completely new 32-bit design
- Which is on assembly level almost backwards compatible with the Neva processor
- A full 40-bit address bus so much more memory access (2 ** 40 = 1099511627776  bytes = 1024 GB)
- But when all segments are zero you got just get a linair 32-bit address field to work
- A 32-bit data bus interface with the memory
- 6 more general purpose registers
- Same memory I/O interface with text output and keyboard input
- Taro video controller intergration
- New segement based memory model vs difficult banking model
- Variable instruction length encoding
- All instructions are conditional
- More flags and so conditions for instructions
- More bitwise instructions

## Some things I like to include in the future:
- A small instruction and data cache (like a Harvard design)
- A small RISC like instruction pipeline
- A hardware interupt system (for keyboard and vsync)

## Instruction encoding:
Like the Neva processor, I have kept the instruction encoding quite simple.

### Immidate micro encoding (2 bytes):
```
opcode mode | dest imm
   5    3   |  4    4
```

### Immidate small encoding (4 bytes):
```
opcode mode | dest cond | imm | imm
   5    3   |  4    4   |  8  |  8
```

### Immidate normal encoding (6 bytes):
```
opcode mode | dest cond | imm | imm | imm | imm
   5    3   |  4    4   |  8  |  8  |  8  |  8
```

### Register micro encoding (2 bytes):
```
opcode mode | dest source
   5    3   |  4     4
```

### Register small encoding (4 bytes):
```
opcode mode | dest cond | source disp | disp
   5    3   |  4    4   |    4    4   |  8
```

### Register normal encoding (6 bytes):
```
opcode mode | dest cond | source disp | disp | disp | enable source2 shift
   5    3   |  4    4   |    4    4   |  8   |  8   |   1       4      3
```

## Modes:
```
0 = immidate mode, micro size
1 = immidate mode, small size
2 = immidate mode, normal size
3 = immidate mode, normal size, address mode (default loads word)

4 = register mode, micro size
5 = register mode, small size
6 = register mode, normal size
7 = register mode, normal size, address mode (default loads word)
```

## Conditions:
```
 0 = - (always) = if (true)
 1 = -n (never) = if (false)
 2 = -c (carry) = if (carry)
 3 = -nc (not carry) = if (!carry)
 4 = -z (zero) = if (zero)
 5 = -nz (not zero) = if (!zero)
 6 = -s (sign) = if (sign)
 7 = -ns (not sign) = if (!sign)
 8 = -o (overflow) = if (overflow)
 9 = -no (not overflow) = if (!overflow)
10 = -a (above) = if (!carry && !zero)
11 = -na (not above) = if (carry || zero)
12 = -l (lesser) = if (sign != overflow)
13 = -nl (not lesser) = if (sign == overflow)
14 = -g (greater) = if (zero && sign == overflow)
15 = -ng (not greater) = if (!zero || sign != overflow)
```

## Registers:
```
 0 = a = General purpose A register
 1 = b = General purpose B register
 2 = c = General purpose C register
 3 = d = General purpose D register
 4 = e = General purpose E register
 5 = f = General purpose F register
 6 = g = General purpose G register
 7 = h = General purpose H register

 8 = ip = Instruction pointer register
 9 = sp = Stack pointer register
10 = bp = Stack Base pointer register
11 = cs = Code segment register
12 = ds = Data segment register
13 = ss = Stack segment register
14 = es = Extra segment register
15 = flags = Flags register
```

## Flags:
```
0 = carry flag
1 = zero flag
2 = sign flag
3 = overflow flag

8 = halted flag
```

## Kora (re)starts jump address
When Kora (re)starts the instruction pointer register is set to `0` and the code segment register is set to `0xffffffff`
So the processor starts executing code at 0xffffffff00

## Instructions:
| #  | Name  | Meaning                          | Operation                                            |
| -- | ----- | -------------------------------- | ---------------------------------------------------- |
| 0  | nop   | no operation                     | \-                                                   |
|    |       |                                  |                                                      |
| 1  | lw    | load word (32-bit)               | dest = data                                          |
| 2  | lhw   | load signed half word (16-bit)   | dast = data & 0xffff (signed)                        |
| 3  | lhwu  | load unsigned half word (16-bit) | dast = data & 0xffff                                 |
| 4  | lb    | load signed byte (8-bit)         | dest = data & 0xff (signed)                          |
| 5  | lbu   | load unsigned byte (8-bit)       | dest = data & 0xff                                   |
| 6  | sw    | store word (32-bit)              | \[data\] = dest                                      |
| 7  | shw   | store half word (16-bit)         | \[data\] = dest & 0xffff                             |
| 8  | sb    | store byte (8-bit)               | \[data\] = dest & 0xff                               |
|    |       |                                  |                                                      |
| 9  | add   | add                              | dest += data                                         |
| 10 | adc   | add with carry                   | dest += data + carry                                 |
| 11 | sub   | subtract                         | dest -= data                                         |
| 12 | sbb   | subtract with borrow             | dest -= data + borrow                                |
| 13 | cmp   | compare                          | dest - data (only set flags)                         |
|    |       |                                  |                                                      |
| 14 | and   | and                              | dest &= data                                         |
| 15 | or    | or                               | dest |= data                                         |
| 16 | xor   | xor                              | dest ^= data                                         |
| 17 | not   | not                              | dest = ~data                                         |
| 18 | shl   | logical shift lift               | dest <<= data & 0x1f                                 |
| 19 | shr   | logical shift right              | dest >>= data & 0x1f                                 |
| 20 | sar   | arithmetic shift right           | dest >>= data & 0x1f (signed)                        |
|    |       |                                  |                                                      |
| 21 | mul   | signed multiply                  | dest \*= data (lower word), h = (higher word)        |
| 22 | mulu  | unsigned multiply                | dest \*= data (lower word), h = (higher word)        |
| 23 | div   | signed divide                    | dest /= data (word), h = (remainder)                 |
| 24 | divu  | unsigned divide                  | dest /= data (word), h = (remainder)                 |
|    |       |                                  |                                                      |
| 25 | jmp   | jump                             | es = cs, cs = dest, ip = data                        |
| 26 | rjmp  | relative jump                    | es = cs, cs = dest, ip += data                       |
| 27 | push  | push                             | \[sp\] = data, sp -= 4                               |
| 28 | pop   | pop                              | sp += 4, dest = \[sp\]                               |
| 29 | call  | call                             | es = cs, cs = dest, \[sp\] = ip, sp -= 4, ip = data  |
| 30 | rcall | relative call                    | es = cs, cs = dest, \[sp\] = ip, sp -= 4, ip += data |
| 31 | ret   | return                           | es = cs, cs = dest, sp += 4 + data, ip = \[sp\]      |
