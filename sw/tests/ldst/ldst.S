.text
.globl _start

_start:
    li x2, 0xfc
    nop;nop;nop;nop;nop;

    sw x2, 0(x0)
    nop;nop;nop;nop;nop;

    lw x3, 0(x0)



