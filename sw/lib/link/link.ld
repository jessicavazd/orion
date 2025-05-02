OUTPUT_FORMAT("elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)

/* MEMORY LAYOUT */
MEMORY
{
    RAM (rwx):       ORIGIN = 0x10000, LENGTH = 64K
}

/* Specify Sections */
SECTIONS
{
    /* .text section */
    .text : {
        *(.boot)                        /* boot sections from startup file */
        *(.text .text.*)                /* text sections */
        *(.rodata .rodata.*)            /* read-only data sections */

        . = ALIGN(4);
        _etext = .;                     /* end of text section */
    } > RAM


    /* .data section */
    .data : {
        _sdata = .;
        *(.data .data.*)                /* data sections */
        
        . = ALIGN(16);
        _global_pointer = . + 0x800;
        
        *(.sdata .sdata.*)              /* static data sections */
        *(.srodata.*)                   /* static read-only data sections */
        
        . = ALIGN(4);
        _edata = .;
    } > RAM


    /* .bss section */
    .bss (NOLOAD) : {
        _sbss = .;
        *(.bss .bss.*)                  /* bss sections */
        *(.sbss .sbss.*)                /* static bss sections */
        *(COMMON)
        
        . = ALIGN(4);
        _ebss = .;
    } > RAM


    /* Spike sections */
    .tohost : {
        KEEP(*(.tohost))            /* tohost sections */
    } > RAM

    .fromhost : { 
        KEEP(*(.fromhost))          /* fromhost sections */
    } > RAM
}

PROVIDE(_stack_pointer  = ORIGIN(RAM) + LENGTH(RAM) - 0x20);
PROVIDE(__vdev_base_addr = ORIGIN(RAM) + LENGTH(RAM) - 0x20);
