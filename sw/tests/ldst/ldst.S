.text
.globl _start

_start:
    li x2, 0x10000
    nop;nop;nop;nop;nop;

    sw x2, 0(x2)
    nop;nop;nop;nop;nop;

    lw x3, 0(x2)

    j _exit




# -------------------------------------------------------------
# exit_spike: Writes to `tohost` to trigger exit in Spike
# -------------------------------------------------------------
.globl _exit
_exit:
    li a0, 1         # any nonzero value
    la t0, tohost    # get address of `tohost`
    sw a0, 0(t0)     # write to tohost (Spike sees it and exits)
    ebreak           # for orionsim

# 1:  j 1b           # hang forever (if Spike doesn’t exit immediately)

# -------------------------------------------------------------
# These sections are recognized by Spike as communication channels
# -------------------------------------------------------------
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