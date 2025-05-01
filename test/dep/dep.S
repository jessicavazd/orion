.text
.globl main

main:
    li  x1, 0x1
    li  x5, 0x5
    add x7, x5, x1
    add x8, x5, x7
    add x9, x1, x7
    add x10, x9, x8
    add x11, x8, x10
    j _exit
