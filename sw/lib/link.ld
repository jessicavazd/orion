OUTPUT_FORMAT("elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)

/* MEMORY LAYOUT */
MEMORY
{
    RAM (rx):       ORIGIN = 0x10000, LENGTH = 64K
}

/* Specify Sections */
SECTIONS
{
    /* .text section */
    .text : {
        *(.text .text.*)
        *(.rodata .rodata.*)
    } > RAM

    /* .data section */
    .data : {
        *(.data .data.*)
    } > RAM

    /* Spike sections */
    .tohost : { *(.tohost) } > RAM
    .fromhost : { *(.fromhost) } > RAM
}