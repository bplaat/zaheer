# Kora 16-bit processor for a Altera Cyclone II FPGA dev board (is the idea)
The Kora processor is a new processor based on the Neva, but extremely expanded and better in every way.
The processor has a classic CISC instruction which is inspired by x86, 68000 and ARM instruction sets.

*This is a prototype instruction set architecture no real implementation is made to until today.*

Made by [Bastiaan van der Plaat](https://bastiaan.ml/)

## Pages that inspired this project
- https://en.wikipedia.org/wiki/Intel_80386
- https://en.wikipedia.org/wiki/ARM_architecture
- https://en.wikipedia.org/wiki/Motorola_68000
- https://en.wikipedia.org/wiki/X86_instruction_listings
- http://unixwiz.net/techtips/x86-jumps.html

## The new things compared to the Neva processor:
- A completely new 16-bit design
- Which is on assembly level almost backwards compatible with the Neva processor
- A full 24-bit address bus so much memory access (2 ** 24 = 16777216 bytes = 16 MB)
- But when all segments are zero you got just get a linair 16-bit address field to work
- A 16-bit data bus interface with the memory
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

### Immidate small encoding (3 bytes):
```
opcode mode | dest cond | imm
   5    3   |  4    4   |  8
```

### Immidate normal encoding (4 bytes):
```
opcode mode | dest cond | imm | imm
   5    3   |  4    4   |  8  |  8
```

### Register micro encoding (2 bytes):
```
opcode mode | dest source
   5    3   |  4     4
```

### Register small encoding (3 bytes):
```
opcode mode | dest cond | source disp
   5    3   |  4    4   |    4    4
```

### Register normal encoding (4 bytes):
```
opcode mode | dest cond | source disp | disp
   5    3   |  4    4   |    4    4   |  8
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
 0 = always = if (true)
 1 = never = if (false)
 2 = jc = if (carry)
 3 = jnc = if (!carry)
 4 = jz = if (zero)
 5 = jnz = if (!zero)
 6 = js = if (sign)
 7 = jns = if (!sign)
 8 = jo = if (overflow)
 9 = jno = if (!overflow)
10 = ja = if (!carry && !zero)
11 = jna = if (carry || zero)
12 = jl = if (sign != overflow)
13 = jnl = if (sign == overflow)
14 = jg = if (zero && sign == overflow)
15 = jng = if (!zero || sign != overflow)
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
When Kora (re)starts the instruction pointer register is set to `0` and the code segment register is set to `0xffff`
So the processor starts executing code at 0xffff00

## Instructions:
```
 0 = nop

# Memory instructions
 1 = lw (load word)
 2 = lb (load byte signed)
 3 = lbu (load byte unsigned)
 4 = sw (store word)
 5 = sb (store byte)

# Arithmetic instructions
 6 = add
 7 = adc
 8 = sub
 9 = sbb
10 = neg
11 = cmp

# Bitwise / Shift instructions
12 = and
13 = or
14 = xor
15 = not
16 = shl
17 = shr
18 = sar

# Jump / Stack instructions
19 = jmp (dest reg is new code bank)
20 = push
21 = pop
22 = call
23 = ret
24 = scall (dest reg is new code bank) (two mem access)
25 = sret (dest reg is new code bank) (two mem access)

# Multiply / Division instructions (extention)
26 = mul (two reg access)
27 = mulu (two reg access)
28 = div (two reg access)
29 = divu (two reg access)

# Reserved opcodes
30 = reserved
31 = reserved
32 = reserved
```
