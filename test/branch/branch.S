    .text
    .globl main

main:
    #-------------------------------------------------------------------
    # BEQ: forward, taken
    #-------------------------------------------------------------------
    li   x1, 42
    li   x2, 42
    beq  x1, x2, BEQ_TAKEN
    // if not taken, x3 = 0
    li   x3, 0
    j    BEQ_DONE
BEQ_TAKEN:
    // if taken, x3 = 1
    li   x3, 1
BEQ_DONE:
    la   x4, res_beq_t
    sw   x3, 0(x4)
    lw   x5, 0(x4)

    #-------------------------------------------------------------------
    # BEQ: forward, not taken
    #-------------------------------------------------------------------
    li   x1, 42
    li   x2, 43
    beq  x1, x2, BEQ_NOT_TAKEN
    # branch not taken → x6 = 1
    li   x6, 1
    j    BEQ_NT_DONE
BEQ_NOT_TAKEN:
    # (would land here if it were taken) → x6 = 0
    li   x6, 0
BEQ_NT_DONE:
    la   x7, res_beq_nt
    sw   x6, 0(x7)
    lw   x8, 0(x7)

    #-------------------------------------------------------------------
    # BNE: forward, taken
    #-------------------------------------------------------------------
    li   x1, 100
    li   x2, 101
    bne  x1, x2, BNE_TAKEN
    li   x9, 0
    j    BNE_DONE
BNE_TAKEN:
    li   x9, 1
BNE_DONE:
    la   x10, res_bne_t
    sw   x9, 0(x10)
    lw   x11, 0(x10)

    #-------------------------------------------------------------------
    # BNE: forward, not taken
    #-------------------------------------------------------------------
    li   x1, 200
    li   x2, 200
    bne  x1, x2, BNE_NOT_TAKEN
    li   x12, 1
    j    BNE_NT_DONE
BNE_NOT_TAKEN:
    li   x12, 0
BNE_NT_DONE:
    la   x13, res_bne_nt
    sw   x12, 0(x13)
    lw   x14, 0(x13)

    #-------------------------------------------------------------------
    # BLT: forward, taken (signed)
    #-------------------------------------------------------------------
    li   x1, -5
    li   x2, 0
    blt  x1, x2, BLT_TAKEN
    li   x15, 0
    j    BLT_DONE
BLT_TAKEN:
    li   x15, 1
BLT_DONE:
    la   x16, res_blt_t
    sw   x15, 0(x16)
    lw   x17, 0(x16)

    #-------------------------------------------------------------------
    # BLT: forward, not taken (signed)
    #-------------------------------------------------------------------
    li   x1, 5
    li   x2, 0
    blt  x1, x2, BLT_NOT_TAKEN
    li   x18, 1
    j    BLT_NT_DONE
BLT_NOT_TAKEN:
    li   x18, 0
BLT_NT_DONE:
    la   x19, res_blt_nt
    sw   x18, 0(x19)
    lw   x20, 0(x19)

    #-------------------------------------------------------------------
    # BGE: forward, taken (signed)
    #-------------------------------------------------------------------
    li   x1, 7
    li   x2, 7
    bge  x1, x2, BGE_TAKEN
    li   x21, 0
    j    BGE_DONE
BGE_TAKEN:
    li   x21, 1
BGE_DONE:
    la   x22, res_bge_t
    sw   x21, 0(x22)
    lw   x23, 0(x22)

    #-------------------------------------------------------------------
    # BGE: forward, not taken (signed)
    #-------------------------------------------------------------------
    li   x1, -1
    li   x2, 0
    bge  x1, x2, BGE_NOT_TAKEN
    li   x24, 1
    j    BGE_NT_DONE
BGE_NOT_TAKEN:
    li   x24, 0
BGE_NT_DONE:
    la   x25, res_bge_nt
    sw   x24, 0(x25)
    lw   x26, 0(x25)

    #-------------------------------------------------------------------
    # BLTU: forward, taken (unsigned)
    #-------------------------------------------------------------------
    li   x1, 1
    li   x2, 2
    bltu x1, x2, BLTU_TAKEN
    li   x27, 0
    j    BLTU_DONE
BLTU_TAKEN:
    li   x27, 1
BLTU_DONE:
    la   x28, res_bltu_t
    sw   x27, 0(x28)
    lw   x29, 0(x28)

    #-------------------------------------------------------------------
    # BLTU: forward, not taken (unsigned)
    #-------------------------------------------------------------------
    li   x1, 0xFFFFFFFF
    li   x2, 0
    bltu x1, x2, BLTU_NOT_TAKEN
    li   x30, 1
    j    BLTU_NT_DONE
BLTU_NOT_TAKEN:
    li   x30, 0
BLTU_NT_DONE:
    la   x31, res_bltu_nt
    sw   x30, 0(x31)
    lw   x5, 0(x31)

    #-------------------------------------------------------------------
    # BGEU: forward, taken (unsigned)
    #-------------------------------------------------------------------
    li   x6, 0xFFFFFFFF
    li   x7, 0
    bgeu x6, x7, BGEU_TAKEN
    li   x8, 0
    j    BGEU_DONE
BGEU_TAKEN:
    li   x8, 1
BGEU_DONE:
    la   x9, res_bgeu_t
    sw   x8, 0(x9)
    lw   x10, 0(x9)

    #-------------------------------------------------------------------
    # BGEU: forward, not taken (unsigned)
    #-------------------------------------------------------------------
    li   x6, 1
    li   x7, 2
    bgeu x6, x7, BGEU_NOT_TAKEN
    li   x11, 1
    j    BGEU_NT_DONE
BGEU_NOT_TAKEN:
    li   x11, 0
BGEU_NT_DONE:
    la   x12, res_bgeu_nt
    sw   x11, 0(x12)
    lw   x13, 0(x12)

    #-------------------------------------------------------------------
    # JAL: forward jump + link
    #-------------------------------------------------------------------
    jal  x14, JAL_TARGET
    # after jump, x14 holds return‐address
    la   x15, res_jal
    sw   x14, 0(x15)
    lw   x16, 0(x15)
    j    JAL_DONE
JAL_TARGET:
    nop
JAL_DONE:

    #-------------------------------------------------------------------
    # JALR: indirect jump + link
    #-------------------------------------------------------------------
    la   x17, JALR_TARGET
    jalr x18, 0(x17)
    # after jump, x18 holds return‐address
    la   x19, res_jalr
    sw   x18, 0(x19)
    lw   x20, 0(x19)
    j    JALR_DONE
JALR_TARGET:
    nop
JALR_DONE:

    #-------------------------------------------------------------------
    # J (alias for jal x0, ...): forward jump, no link
    #-------------------------------------------------------------------
    j    J_TARGET
    // if alias failed, fall through:
    li   x21, 0xdeadbeef
    j    J_DONE
J_TARGET:
    li   x21, 0xcafebabe
J_DONE:
    la   x22, res_j
    sw   x21, 0(x22)
    lw   x23, 0(x22)

    #-------------------------------------------------------------------
    # Exit
    #-------------------------------------------------------------------
    j    _exit


    #-------------------------------------------------------------------
    # Data section: one word per test
    #-------------------------------------------------------------------
    .data
res_beq_t:    .word 0
res_beq_nt:   .word 0
res_bne_t:    .word 0
res_bne_nt:   .word 0
res_blt_t:    .word 0
res_blt_nt:   .word 0
res_bge_t:    .word 0
res_bge_nt:   .word 0
res_bltu_t:   .word 0
res_bltu_nt:  .word 0
res_bgeu_t:   .word 0
res_bgeu_nt:  .word 0
res_jal:      .word 0
res_jalr:     .word 0
res_j:        .word 0