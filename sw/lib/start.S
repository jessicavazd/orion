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
    // a0 contains exit code
    andi a0, a0, 0xff   # 1 Byte return code supported
    
    // Spike exit routine
    li t0, 1            # any nonzero value
    la t1, tohost       # get address of `tohost`
    sw t0, 0(t1)        # write to tohost (Spike sees it and exits)

    // Orionsim exit routine
    la  t0, __vdev_base_addr
    ori a0, a0, 0x100   # Set finish request bit
    sw  a0, 0x1c(t0)    # Write return code to VDEV_SIMCTRL_ADDR
    
    ebreak              # This forces spike to immediately exit
    nop;nop;nop;nop;    # Fill up the pipeline after ebreak to prevent garbage execution

    // Unreachable (inf loop)
1:  j 1b


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