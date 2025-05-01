.text
.globl main

main:
    la x1, data0

    li x2, 0xdeadbeef

    lw x3, 0(x1)
    sw x2, 0(x1)
    lw x4, 0(x1)

    j _exit


.data
data0:
    .word 0xbabecafe
