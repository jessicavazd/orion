.text
.globl main

main:
    addi x7, x0, 10   # x7 = 10
    addi x6, x0, 20   # x6 = 20
    add x7, x7, x6    # x7 = x7 + x6 (10 + 20)

    j _exit

