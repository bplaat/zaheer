MEMORY {
    BRAM (RWX) : ORIGIN = 0, LENGTH = 4096
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
