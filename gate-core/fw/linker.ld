/* WCET-friendly memory layout */
MEMORY {
    ROM (rx) : ORIGIN = 0x08000000, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 8K
}

SECTIONS {
    .text : {
        *(.text.validate_cert)
        *(.text.compute_lambda_cost)
        *(.text)
        *(.rodata)
    } > ROM

    .data : {
        *(.data*)
    } > RAM AT > ROM

    .bss : {
        *(.bss*)
        *(COMMON)
    } > RAM

    .stack (NOLOAD) : {
        . = ALIGN(8);
        _stack_end = .;
        . += 256;  /* 256B fixed stack */
        _stack_top = .;
    } > RAM

    /DISCARD/ : {
        *(.note*)
        *(.comment*)
    }
}
