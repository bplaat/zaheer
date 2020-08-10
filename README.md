# Kora 32-bit processor
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
- A completely new 32-bit design
- Which is on assembly level almost backwards compatible with the Neva processor
- A full 40-bit address bus so much memory access (2 ** 40 = 1099511627776 bytes = ~1024 GB)
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
- An instruction extension system with CPUID instruction to detect extenstions
- A hardware interupt system
- Integer Multiply and division instructions extension

## Instruction encoding:
Like the Neva processor, I have kept the instruction encoding quite simple.

*I know that the instructions are to big and I'm working on a smaller version for each instruction.*

### Immidate instruction encoding:
```
opcode mode | dest cond | imm | imm | imm | imm
   5    3   |  4    4   |  8  |  8  |  8  |  8
```

### Register instruction encoding:
```
opcode mode | dest cond | source disp | disp | disp source | source shift
   5    3   |  4    4   |    4    4   |  8   |  7     1    |    3     5
```

## Modes:
```
0 = data = imm
1 = address = imm, data = byte [address]
2 = address = imm, data = hword [address]
3 = address = imm, data = word [address]
4 = data = reg + dis + reg << shift
5 = address = reg + dis + reg << shift, data = byte [address]
6 = address = reg + dis + reg << shift, data = hword [address]
7 = address = reg + dis + reg << shift, data = word [address]
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
When Kora (re)starts the instruction pointer register is set to `0` and the code segment register is set to `0xffffffff`
So the processor starts executing code at 0xffffffff00

## Instructions:
```
 0 = nop

# Memory instructions
 1 = load
 2 = store byte
 3 = store hword
 4 = store word

# Arithmetic instructions
 5 = add
 6 = adc
 7 = sub
 8 = sbb
 9 = neg
10 = cmp

# Bitwise / Shift instructions
11 = and
12 = or
13 = xor
14 = not
15 = shl
16 = shr
17 = sar

# Jump / Stack instructions
18 = jmp (dest reg is new code bank)
19 = push
20 = pop
21 = call
22 = ret
23 = segcall (dest reg is new code bank) (two mem access)
24 = segret (dest reg is new code bank) (two mem access)
```

## Some assembly code scrambles:
```
moveq a, 0x12345678
movgt b, 0x1234

mov a, [sp - 0x40]
and a, 0x000000ff

push b + 0x50

mov [sp], b + 0x50
add sp, 4

mov a, 0x6000
ret c - 0x30 + es << 32
ret c - 0x30 + es * 4294967296

pop a

mov ip, 0x50
subeq ip, 0x30

// numbers[x]
mov b, [bp - 400 + e << 2]

mov c, e
shl c, 2
add c, bp
mov a, [c - 400]
```
