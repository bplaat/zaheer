# Kora 32-bit processor
The Kora processor is a new processor based on the Neva, but extremely expanded and better in every way.
The processor has a classic CISC instruction which is inspired by x86, 68000 and ARM instruction sets.

Made by [Bastiaan van der Plaat](https://bastiaan.ml/)

## The new things compared to the Neva processor:
- A completely new 32-bit design
- Which is on assembly level almost backwards compatible with the Neva processor
- A full 40-bit address bus so much memory access (2**40 = 1099511627776 bytes = ~1024 GB)
- But when all segments are zero you got just a linair 32-bit address field to work
- A 32-bit data bus interface with the memory
- 6 more general purpose registers
- Same memory I/O interface with text output and keyboard input
- Taro video controller intergration
- New segement based memory model vs difficult banking model
- Variable instruction length encoding
- 8 hardware interupt lines
- All instructions are conditional
- More flags and so conditions for instructions
- More bitwise instructions
- Instruction extension system with CPUID instruction
- Multiply and division instructions extension

## Instruction encoding:
Immidate data mode instruction encoding:
```
opcode regm largem addrm | dest cond | imm | imm
   5   1=0    1=0    1   |  4    4   |  8  |  8
```

Immidate data mode large instruction encoding:
```
opcode regm largem addrm | dest cond | imm | imm | imm | imm
   5   1=0    1=1    1   |  4    4   |  8  |  8  |  8  |  8
```

Register data mode instruction encoding:
```
opcode regm largem addrm | dest cond | source disp | disp
   5   1=1    1=0    1   |  4    4   |    4    4   |  8
```

Register data mode large instruction encoding:
```
opcode regm largem addrm | dest cond | source disp | disp | disp | source shift
   5   1=1    1=1    1   |  4    4   |    4    4   |  8   |  8   |    4     4
```

Some assembly code scrambles:
```
moveq a, 0x12345678
movgt b, 0x1234

mov a, [sp - 0x40]
and a, 0x000000ff

push b + 0x50

mov [sp], b + 0x50
add sp, 4

mov a, 0x6000
ret c - 0x30 + es << 2
ret c - 0x30 + es * 8


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

## Conditions:
```
 0 = always = if (true)
 1 = jc = if (carry)
 2 = jnc = if (!carry)
 3 = jz = if (zero)
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
16 = interrupt flag
```

## Kora (re)starts jump address
When Kora (re)starts it jumps to to the code segemnt stored at `0xfffffffff7` and the address at `0xfffffffffb`

## Hardware interupts
Locations stored at `00:64`

When one off the interupt lines is set high the processor finishes the current instruction and calls the interupt address at the beginning of memory.

## Instructions:
```
# CPU / Load / Store instructions
 0 = nop
 1 = cpuid
    a = BAST                ; Manufacturer name 8 ASCII bytes
    b = IAAN
    c = KORA                ; Processor name 8 ASCII bytes
    d = LUXE
    e = 0001 0002           ; Version 1.2
    f = 00000000 00000000   ; Features bit array
        00000000 00000011   ; 0 = Interrupts Extension
                            ; 1 = Integer Multiplication and Division Extension
 2 = hlt
 3 = load
 4 = store

# Arithmetic instructions
 3 = add
 4 = adc
 5 = sub
 6 = sbb
 7 = neg
 8 = cmp

# Bitwise instructions
 9 = and
10 = or
11 = xor
12 = not

# Shift and rotate instructions
13 = shl
14 = shr
sal = shl
15 = sar
16 = rol
17 = ror

# Stack instructions
-- dest register is new code bank
18 = jmp
19 = push
20 = pop
21 = call
22 = ret

# Interupt extension instructions
?

# Integer Multiplication and Division Extension
?
0x40 = mul = unsigned
0x41 = smul = signed
0x42 = div = unsigned ?
0x43 = sdiv = signed ?
0x44 = mod = unsigned ?
0x45 = smod = signed ?
```

## Reference pages:
- https://en.wikipedia.org/wiki/X86_instruction_listings
- http://unixwiz.net/techtips/x86-jumps.html
