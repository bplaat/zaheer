MEMORY {
    BRAM (RWX) : ORIGIN = 0, LENGTH = 0x2000
}

SECTIONS {
    . = ALIGN(4);
    .text : {
        *(.text._start)
        *(.text)
    } > BRAM
    .data : {
        *(.data)
    } > BRAM
    .bss : {
        *(.bss)
    } > BRAM
}
