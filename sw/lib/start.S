.section .boot, "ax", @progbits
.global _start
.global _exit


# ===== Startup code =====
_start:
.option norvc
    # ===== initialization =====
    # initialize sp & gp
    la sp, _stack_pointer       # set stack pointer
.option push
.option norelax
    la gp, _global_pointer      # set global pointer
.option pop

    li a0, 0
    li a1, 0

    # ===== main program =====
    jal main
    
    j _exit


# ===== exit function =====
_exit:
    li t1, 1                # any nonzero value
    la t0, tohost           # get address of `tohost`
    sw t1, 0(t0)            # write to tohost (Spike sees it and exits)
    jal exit                # for orionsim
    nop;nop;nop;nop;        # Fill up the pipeline after ebreak to prevent garbage execution


# ---------------------------------------
# These sections are recognized by Spike
# ---------------------------------------
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