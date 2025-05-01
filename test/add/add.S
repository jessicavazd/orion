.text
.globl _start

_start:
    addi x7, x0, 10   # x7 = 10
    nop
    nop
    nop
    nop
    nop

    addi x6, x0, 20   # x6 = 20
    nop
    nop
    nop
    nop
    nop

    add x7, x7, x6    # x7 = x7 + x6 (10 + 20)
    nop
    nop
    nop
    nop
    nop

    ebreak

