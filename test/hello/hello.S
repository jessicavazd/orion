.equ CONSOLE_ADDR, 0x1FFFc

.text
.globl _start

_start:
    la a0, msg
    jal putstr
    j _exit

.data
    msg:
    .asciz "Hello World!\n -- from Orion Core\n\n"

# -------------------------------------------------------------
# putstr: Prints a null-terminated string to the console
# -------------------------------------------------------------
.text
putstr:
    # s0 = a0 = base address of string
    mv s0, a0
    mv s4, ra   # store return address elsewhere
loop:
    lb  t0, 0(s0)                   # load byte from string 
    beq t0, x0, ret_putstr          # return if null
    mv a0, t0                       # otherwise print it
    jal putchar
    addi s0, s0, 1                  # increment string pointer 
    j loop
ret_putstr:
    mv ra, s4                       # restore return address
    ret

# -------------------------------------------------------------
# putchar: Prints a character to the console
# -------------------------------------------------------------
.text
putchar:
    # a0 = character
    # t1 = tx_address
    li t1, CONSOLE_ADDR
    sb  a0, 0(t1)
    ret


# -------------------------------------------------------------
# exit_spike: Writes to `tohost` to trigger exit in Spike
# -------------------------------------------------------------
.text
.globl _exit
_exit:
    li a0, 1         # any nonzero value
    la t0, tohost    # get address of `tohost`
    sw a0, 0(t0)     # write to tohost (Spike sees it and exits)
    ebreak           # for orionsim
    nop;nop;nop;nop; # Fill up the pipeline after ebreak to prevent garbage execution

# 1:  j 1b           # hang forever (if Spike doesn’t exit immediately)

# -------------------------------------------------------------
# These sections are recognized by Spike as communication channels
# -------------------------------------------------------------
.data
.section .tohost, "aw", @progbits
.globl tohost
.align 4
tohost:
    .word 0

.section .fromhost, "aw", @progbits
.globl fromhost
.align 4
fromhost:
    .word 0