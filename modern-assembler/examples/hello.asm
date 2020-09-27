start:
    mov ds, es
    mov ss, es
    mov sp, end + 0x80

    push message
    call print_string

    hlt

print_string:
    push bp
    mov bp, sp

    mov a, word [sp + 2]
.repeat:
    mov b, byte [a]
    cmp b, 0
    je .done
    mov byte [0x00ff], b
    inc a
    jmp .repeat

.done:
    mov sp, bp
    pop bp
    ret 2

message db 'Hello World!', 10, 0

end:
