# The Zuko Operating System
For the Mako Computer System

## Features
- Simple MS-DOS like operating system
- FAT32 file system on a micro-SD card
- Single process: one program can run at a time
- Single kernel syscall API: file I/O, time...

## Calling convention
This is the default calling convention for the Zuko Operating System and the Kora processor in general

### Registers
All general registers are aliased when specific names it is recommended to use these names in your program code instead of the default registry names for clarity.

<table>
<tr><th>#</th><th>Names</th><th>Meaning</th></tr>
<tr><td>0</td><td><code>r0</code>, <code>a</code>, <code>t0</code></td><td>Temporary variable 1 / Variable arguments count</td></tr>
<tr><td>1</td><td><code>r1</code>, <code>b</code>, <code>t1</code></td><td>Temporary variable 2</td></tr>
<tr><td>2</td><td><code>r2</code>, <code>c</code>, <code>t2</code></td><td>Temporary variable 3</td></tr>
<tr><td>3</td><td><code>r3</code>, <code>d</code>, <code>s0</code></td><td>Saved variable 1</td></tr>
<tr><td>4</td><td><code>r4</code>, <code>e</code>, <code>s1</code></td><td>Saved variable 2</td></tr>
<tr><td>5</td><td><code>r5</code>, <code>f</code>, <code>s2</code></td><td>Saved variable 3</td></tr>
<tr><td>6</td><td><code>r6</code>, <code>g</code>, <code>s2</code></td><td>Saved variable 4</td></tr>
<tr><td>7</td><td><code>r7</code>, <code>h</code>, <code>a0</code></td><td>Function argument 1 / Return argument 1</td></tr>
<tr><td>8</td><td><code>r8</code>, <code>i</code>, <code>a1</code></td><td>Function argument 2 / Return argument 2</td></tr>
<tr><td>9</td><td><code>r9</code>, <code>j</code>, <code>a2</code></td><td>Function argument 3</td></tr>
<tr><td>10</td><td><code>r10</code>, <code>k</code>, <code>a3</code></td><td>Function argument 4</td></tr>
<tr><td>11</td><td><code>r11</code>, <code>l</code>, <code>bp</code></td><td>Stack base pointer</td></tr>
</table>

### Function arguments passing
The first four arguments in registers `a0`, `a1`, `a2`, `a3` and the rest pushed to the stack in reverse order

When **fixed function arguments count**:
- Callee clean up via the `ret arguments_stack_size` instruction

When **variable function arguments count**:
- Argument count in the `t0` register before function call
- Caller clean up via the `add sp, arguments_stack_size` instruction after function call

### Fixed arguments count example:
```
test:
    push bp
    mov bp, sp

    ; Create local int variable
    sub sp, 2
    mov t0, 5
    mov [bp - 2], t0

    ; Sum all arguments and local variable
    add a0, a1
    add a0, a2
    add a0, a3
    mov t0, [bp + 4]
    add a0, t0
    mov t0, [bp + 6]
    add a0, t0
    mov t0, [bp - 2]
    add a0, t0

    mov sp, bp
    pop bp
    ret 4 ; Fixed arguments count: callee stack clean up

some_where_else:
    push 6
    push 5
    mov a3, 4
    mov a2, 3
    mov a1, 2
    mov a0, 1
    call test
    ; Fixed arguments count: no caller stack clean up
```

### Variable arguments count example
```
; int sum(...);
sum:
    push bp
    mov bp, sp

    mov s0, 0 ; Argument index variable
    mov s1, 0 ; Sum variable
    mov s2, 0 ; Stack arguments position variable

.repeat:
    cmp s0, t0
    jmp.e .done

    ; When argument index < 4 check registers
    cmp s0, 0
    add.e s1, a0
    cmp s0, 1
    add.e s1, a1
    cmp s0, 2
    add.e s1, a2
    cmp s0, 3
    add.e s1, a3

    cmp s0, 4
    jmp.l .repeat

    ; When argument index >= 4 check stack
    mov t1, bp + 2
    add t1, s2
    mov t0, [t1]
    add s1, t0
    add s2, 2
    jmp .repeat

.done:
    mov a0, s1
    mov sp, bp
    pop bp
    ret ; Variable arguments count: no callee stack clean up

some_where_else:
    ; sum(1, 2, 3, 4, 5, 6)
    push 6
    push 5
    mov a3, 4
    mov a2, 3
    mov a1, 2
    mov a0, 1
    mov t0, 6 ; Variable arguments count: arguments count
    call sum
    add sp, 4 ; Variable arguments count: caller stack clean up
```
