OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    /* Code and read-only data at address 0 */
    . = 0x0;

    .text : {
        *(.text .text.*)
    }

    .rodata : {
        *(.rodata .rodata.*)
    }
}
