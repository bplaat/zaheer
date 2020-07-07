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

# Data sizes
The processor uses the little endian notion and these size terms:
```
byte = 1 byte = 8 bits number
hword (half word) / short = 2 bytes = 16 bits number
sword (strange word) = 3 bytes = 24 bits number
word / int = 4 bytes = 32 bits number
```

## Instruction encoding:
Register encoding:
```
opcode  addr |  mode   size   cond  |  dest  source
7 bits 1 bit | 2 bits 2 bits 4 bits | 4 bits 4 bits
```

Byte immidiate encoding:
```
opcode  addr |  mode   size   cond  |  dest  source |  imm
7 bits 1 bit | 2 bits 2 bits 4 bits | 4 bits 4 bits | 8 bits
```

Short immidiate encoding:
```
opcode  addr |  mode   size   cond  |  dest  source |  imm   |  imm
7 bits 1 bit | 2 bits 2 bits 4 bits | 4 bits 4 bits | 8 bits | 8 bits
```

Int immidiate encoding:
```
opcode  addr |  mode   size   cond  |  dest  source |  imm   |  imm   |  imm   |  imm
7 bits 1 bit | 2 bits 2 bits 4 bits | 4 bits 4 bits | 8 bits | 8 bits | 8 bits | 8 bits
```

## Modes:
With the address mode bit set to zero:
```
0 = 2 bytes = data = source
1 = 3 bytes = data = source + byte
2 = 4 bytes = data = source + short
3 = 6 bytes = data = source + int
```

With the address mode bit set to one:
```
0 = 2 bytes = address = (ds << 8) + source, data = [address]
1 = 3 bytes = address = (ds << 8) + source + byte, data = [address]
2 = 4 bytes = address = (ds << 8) + source + short, data = [address]
3 = 6 bytes = address = (ds << 8) + source + int, data = [address]
```

## Sizes:
```
0 = 8 bits = byte
1 = 16 bits = hword (short)
2 = 24 bits = sword
3 = 32 bits = word (int)
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
 0 = z = Zero register
 1 = a = General purpose A register
 2 = b = General purpose B register
 3 = c = General purpose C register
 4 = d = General purpose D register
 5 = e = General purpose E register
 6 = f = General purpose F register
 7 = g = General purpose G register
 8 = h = General purpose H register
 9 = ip = Instruction pointer register
10 = sp = Stack pointer register
11 = bp = Stack Base pointer register
12 = cs = Code segment register
13 = ds = Data segment register
14 = ss = Stack segment register
15 = flags = Flags register
```

## Flags:
```
0 = carry flag
1 = zero flag
2 = sign flag
3 = overflow flag
8 = interrupt flag
```

## Kora (re)starts jump address
When Kora (re)starts it jumps to to the code segemnt stored at `0xfffffffff7` and the address at `0xfffffffffb`

## Hardware interupts
Locations stored at `00:64`

When one off the interupt lines is set high the processor finishes the current instruction and calls the interupt address at the beginning of memory.

## Instructions:
```
# CPU / Load / Store instructions
0x00 = nop
0x01 = cpuid
    a = BAST                ; Manufacturer 8 ASCII bytes
    b = IAAN
    c = KORA                ; Processor Code Name 4 ASCII bytes
    d = 0001 0002           ; Version 1.2
    e = 00000000 00000000    ; Features bit array
        00000000 00000001    ; 0 = Integer Multiplication and Division Extension
0x02 = hlt
0x03 = load
0x04 = store

# Arithmetic instructions
0x10 = add
0x11 = adc
0x12 = sub
0x13 = sbb
0x14 = cmp
0x15 = neg

# Bitwise instructions
0x20 = and
0x21 = or
0x22 = xor
0x23 = not
0x24 = shl = unsigned
0x25 = shr = unsigned
0x26 = sal = signed
0x27 = sar = signed
0x28 = rol
0x29 = ror

# Jump / Stack instructions
0x30 = jmp
0x31 = push
0x32 = pop
0x33 = call
0x34 = ret

# Integer Multiplication and Division Extension
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
