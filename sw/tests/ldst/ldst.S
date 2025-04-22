.text
.globl _start

_start:
    la x1, data0

    li x2, 0xdeadbeef

    lw x3, 0(x1)
    sw x2, 0(x1)
    lw x4, 0(x1)

    j _exit


.data
data0:
    .word 0xbabecafe



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