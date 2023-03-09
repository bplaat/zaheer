# The Kora 32-bit Processor
The Kora processor is a simple 32-bit CISC processor with RISC features

## Pages that inspired the Kora processor
- https://en.wikipedia.org/wiki/Intel_8086
- https://en.wikipedia.org/wiki/ARM_architecture
- https://en.wikipedia.org/wiki/Motorola_68000
- https://en.wikipedia.org/wiki/RISC-V
- https://en.wikipedia.org/wiki/I386
- https://en.wikipedia.org/wiki/X86_instruction_listings
- http://unixwiz.net/techtips/x86-jumps.html

## Features
- A new simple 32-bit CISC design with RISC features like the Neva processor
- 32-bit internal address bus
- 8-bit external data bus
- Small instruction size
- Room for more instructions

## Insperations
- Many registers for an efficient calling convention: ARM, RISC-V
- Memory access only in special load / store instructions: ARM, RISC-V
- Conditional code for every instruction: ARM
- Flags and condition combinations: x86
- A simple processor interrupt system like the 6502
- Standard interupt and reset address vector: 6502

## Instruction encoding
Every instruction has an opcode and a mode. The mode are two bits that descripe how the instruction must be parsed and executed:

Register small mode (mode = 0)
```
opcode mode | dest src
  6     2   |  4    4
```
Register large mode (mode = 1)
```
opcode mode | dest src | disp | disp
  6     2   |  4    4  |  8   |  8
```
Immediate small mode (mode = 2)
```
opcode mode | dest imm
  6     2   |  4    4
```
Immediate large mode (mode = 3)
```
opcode mode | dest imm | imm | imm
  6     2   |  4    4  |  8  |  8
```

## Registers
The Kora processor has way more registers than the Neva processor, this ensures that code can better be optimized. All registers have names and are used by the Kora ABI in a specific way:

<table>
<tr><th>#</th><th>Names</th><th>Meaning (calling convention)</th></tr>

<tr><td colspan="3"><i>Temporary variables:</i></td></tr>
<tr><td>0</td><td><code>t0</code></td><td>Temporary variable 1 / Variable arguments count</td></tr>
<tr><td>1</td><td><code>t1</code></td><td>Temporary variable 2</td></tr>
<tr><td>2</td><td><code>t2</code></td><td>Temporary variable 3</td></tr>
<tr><td>3</td><td><code>t3</code></td><td>Temporary variable 4</td></tr>
<tr><td>4</td><td><code>t4</code></td><td>Temporary variable 5</td></tr>
<tr><td colspan="3"></td></tr>

<tr><td colspan="3"><i>Saved variables:</i></td></tr>
<tr><td>5</td><td><code>s0</code></td><td>Saved variable 1</td></tr>
<tr><td>6</td><td><code>s1</code></td><td>Saved variable 2</td></tr>
<tr><td>7</td><td><code>s2</code></td><td>Saved variable 3</td></tr>
<tr><td>8</td><td> <code>s3</code></td><td>Saved variable 4</td></tr>
<tr><td colspan="3"></td></tr>

<tr><td colspan="3"><i>Argument variables:</i></td></tr>
<tr><td>9</td><td><code>a0</code></td><td>Function argument 1 / return value 1</td></tr>
<tr><td>10</td><td><code>a1</code></td><td>Function argument 2 / return value 2</td></tr>
<tr><td>11</td><td><code>a2</code></td><td>Function argument 3</td></tr>
<tr><td>12</td><td><code>a3</code></td><td>Function argument 4</td></tr>
<tr><td colspan="3"></td></tr>

<tr><td colspan="3"><i>Special registers:</i></td></tr>
<tr><td>13</td><td><code>bp</code></td><td>Stack base pointer</td></tr>
<tr><td>14</td><td><code>sp</code></td><td>Stack pointer</td></tr>
<tr><td>15</td><td><code>flags</code></td><td>Flags</td></tr>
</table>

## Flag register bits
The Kora processor has general flags and processor state flags, all flags are stored in the `flags` register:

<table>
<tr><th>#</th><th>Name</th><th>Meaning</th></tr>

<tr><td colspan="4"><i>General flags:</i></td></tr>
<tr><td>0</td><td>Zero</td><td>Is set when the result is zero</td></tr>
<tr><td>1</td><td>Sign</td><td>Is set when the sign bit is set</td></tr>
<tr><td>2</td><td>Carry</td><td>Is set when a carry overflow occurs</td></tr>
<tr><td>3</td><td>Overflow</td><td>Is set when a overflow occurs</td></tr>
<tr><td colspan="4"></td></tr>

<tr><td>4/7</td><td><i>Reserved</i></td><td>-</td></tr>
<tr><td colspan="4"></td></tr>

<tr><td colspan="4"><i>Processor state flags:</i></td></tr>
<tr><td>8</td><td>Halt</td><td>When set halts the processor</td></tr>
<tr><td colspan="4"></td></tr>

<tr><td>9/15</td><td><i>Reserved</i></td><td>-</td></tr>
</table>

## Opcodes
TODO
```
; Move, load, store opcodes
0 mov
1 lw
2 lh
3 lhsx
4 lb
5 lbsx
6 sw
7 sh
8 sb

; Arithmetic opcodes
9 add
10 adc
11 sub
12 sbb
13 neg
14 cmp

; Bitwise opcodes
15 and
16 or
17 xor
18 not
19 test
20 shl
21 shr
22 sar

; Jump opcodes
23 jmp dest = 0
23 jz  dest = 2
23 jnz dest = 3
23 js  dest = 4
23 jns dest = 5
23 jc  dest = 6
23 jnc dest = 7
23 jo  dest = 8
23 jno dest = 9
23 ja  dest = 10
23 jna dest = 11
23 jl  dest = 12
23 jnl dest = 13
23 jg  dest = 14
23 jng dest = 15

; Stack opcodes
24 push
25 pop
26 call
27 ret
```

## Assembly examples
Here are some assembly examples:
```asm
; memcpy, memset, memcmp
memcpy:
    ; a0 = dest
    ; a1 = src
    ; a2 = size
    mov t0, a0
    add t0, a2
.repeat:
    cmp a0, t0
    je .done
    mov t1, byte [a1]
    mov byte [a0], t1
    inc a0
    inc a1
    jmp .repeat
.done:
    ret
```
```asm
memset:
    ; a0 = dest
    ; a1 = value
    ; a2 = size
    mov t0, a0
    add t0, a2
.repeat:
    cmp a0, t0
    je .done
    mov byte [a0], a1
    inc a0
    jmp .repeat
.done:
    ret
```

```asm
; strlen, strcpy, strcat, strcmp
strlen:
    ; a0 = str
    mov a1, a0
.repeat:
    mov t1, byte [a0]
    cmp t1, 0
    je .done
    inc a0
    jmp .repeat
.done:
    sub a0, a1
    ret
```
```asm
strcpy:
    ; a0 = dest
    ; a1 = src
.repeat:
    mov t0, byte [a1]
    cmp t0, 0
    je .done
    mov byte [a0], t0
    inc a0
    inc a1
    jmp .repeat
.done:
    ret
```
```asm
strcat:
    ; a0 = dest
    ; a1 = src
.repeat:
    mov t0, byte [a0]
    cmp t0, 0
    je .done
    inc a0
    jmp .repeat
.done:
    call strcpy
    ret
```
