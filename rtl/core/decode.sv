`include "utils.svh"

module decode 
import orion_types::*;
(
    input logic         clk_i,
    input logic         rst_i,
    input logic         flush_req,

    input if_id_t       if_id_i,
    input wb_id_t       wb_id_i,
    output id_ex_t      id_ex_o
);

    logic [31:0] instr /* verilator public */; 
    assign instr = if_id_i.instr;

    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1_s;
    logic [4:0]  rs2_s;
    logic [4:0]  rd_s;
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;

    assign opcode  = instr[6:0];
    assign funct3  = instr[14:12];
    assign funct7  = instr[31:25];
    assign rs1_s   = instr[19:15];
    assign rs2_s   = instr[24:20];
    assign rd_s    = instr[11:7];
    assign imm_i   = {{20{instr[31]}}, instr[31:20]};
    assign imm_s   = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b   = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u   = {instr[31:12], 12'b0};
    assign imm_j   = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    logic [XLEN-1:0] rs1_v;
    logic [XLEN-1:0] rs2_v;

    regfile reg_f (
        .clk_i(clk_i),
        .rst_i(rst_i),

        // Read ports
        .rs1_s_i(rs1_s),
        .rs2_s_i(rs2_s),
        .rs1_v_o(rs1_v),
        .rs2_v_o(rs2_v),

        // Write ports (writeback)
        .rd_s_i(wb_id_i.rd_s), 
        .rd_v_i(wb_id_i.rd_v),
        .we_i(wb_id_i.rd_we)
    );

    always_comb begin 
        id_ex_o.alu_op          = ALU_OP_ADD;
        id_ex_o.cmp_op          = CMP_OP_EQ;
        id_ex_o.rd_we           = 1'b0;
        id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
        id_ex_o.alu_sel_b_imm   = 1'b0;
        id_ex_o.cmp_sel_b_imm   = 1'b0;
        id_ex_o.sel_wb_mux      = WB_MUX_ALU;
        id_ex_o.ld_str_type     = funct3_load_store_t'(funct3);
        id_ex_o.is_load        = 1'b0;
        id_ex_o.is_store       = 1'b0;

        unique case (opcode) 
            OP_REG : begin
                unique case (funct3)
                    FUNCT3_ADD  : id_ex_o.alu_op = funct7[5] ? ALU_OP_SUB : ALU_OP_ADD;
                    FUNCT3_SLL  : id_ex_o.alu_op = ALU_OP_SLL;
                    FUNCT3_XOR  : id_ex_o.alu_op = ALU_OP_XOR;
                    FUNCT3_SR   : id_ex_o.alu_op = funct7[5] ? ALU_OP_SRA : ALU_OP_SRL;
                    FUNCT3_OR   : id_ex_o.alu_op = ALU_OP_OR;
                    FUNCT3_AND  : id_ex_o.alu_op = ALU_OP_AND;
                    FUNCT3_SLT  : begin
                                    id_ex_o.cmp_op      = CMP_OP_LT;
                                    id_ex_o.sel_wb_mux  = WB_MUX_CMP;
                                end
                    FUNCT3_SLTU : begin
                                    id_ex_o.cmp_op      = CMP_OP_LTU;
                                    id_ex_o.sel_wb_mux  = WB_MUX_CMP;
                                end
                    default     : id_ex_o.alu_op = ALU_OP_ADD;
                endcase
                id_ex_o.alu_sel_b_imm   = 1'b0;
                id_ex_o.cmp_sel_b_imm   = 1'b0;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_IMM : begin;
                unique case (funct3)
                    FUNCT3_ADD : id_ex_o.alu_op = funct7[5] ? ALU_OP_SUB : ALU_OP_ADD;
                    FUNCT3_SLL : id_ex_o.alu_op = ALU_OP_SLL;
                    FUNCT3_XOR : id_ex_o.alu_op = ALU_OP_XOR;
                    FUNCT3_SR  : id_ex_o.alu_op = funct7[5] ? ALU_OP_SRA : ALU_OP_SRL;
                    FUNCT3_OR  : id_ex_o.alu_op = ALU_OP_OR;
                    FUNCT3_AND : id_ex_o.alu_op = ALU_OP_AND;
                    FUNCT3_SLT : begin
                                    id_ex_o.cmp_op      = CMP_OP_LT;
                                    id_ex_o.sel_wb_mux  = WB_MUX_CMP;
                                end
                    FUNCT3_SLTU : begin
                                    id_ex_o.cmp_op      = CMP_OP_LTU;
                                    id_ex_o.sel_wb_mux  = WB_MUX_CMP;
                                end
                    default     : id_ex_o.alu_op = ALU_OP_ADD;
                endcase 
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.cmp_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_i;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_LUI: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_ZERO;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_u;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_AUIPC: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_PC;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_u;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_LOAD: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_i;
                id_ex_o.rd_we           = 1'b1;
                id_ex_o.sel_wb_mux      = WB_MUX_MEM;
                id_ex_o.is_load        = 1'b1;
            end
            OP_STORE: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_s;
                id_ex_o.rd_we           = 1'b0;
                id_ex_o.sel_wb_mux      = WB_MUX_MEM;
                id_ex_o.is_store        = 1'b1;
            end
            OP_JAL: begin
                // calculate target addr = pc + imm_j
                // set pc_next = target addr
                // set rd = pc + 4
                // flush  //fixme
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_PC;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_j;
                id_ex_o.rd_we           = 1'b1;
                id_ex_o.sel_wb_mux      = WB_MUX_PC_NEXT;
                id_ex_o.is_jump         = 1'b1;
            end
            OP_JALR: begin
                // calculate target addr = rs1 + imm_i
                // set pc_next = target addr
                // set rd = pc + 4
                // flush //fixme
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_i;
                id_ex_o.rd_we           = 1'b1;
                id_ex_o.sel_wb_mux      = WB_MUX_PC_NEXT;
                id_ex_o.is_jump         = 1'b1;
            end
            OP_BRANCH: begin
                // calculate target addr = pc + imm_b
                // set pc_next = target addr
                // cmp rs1 & rs2 & set br_taken accordingly
                // flush //fixme
                id_ex_o.alu_op              = ALU_OP_ADD;
                id_ex_o.alu_sel_a           = ALU_SEL_A_PC;
                id_ex_o.alu_sel_b_imm       = 1'b1;
                id_ex_o.imm                 = imm_b;
                id_ex_o.rd_we               = 1'b0;
                id_ex_o.cmp_sel_b_imm       = 1'b0;
                id_ex_o.cmp_op              = cmp_ops_t'(funct3);
                id_ex_o.is_jump             = 1'b1;
                id_ex_o.is_jump_conditional = 1'b1;
            end
        default : begin
        end
        endcase
    end

    assign id_ex_o.valid = flush_req ? 1'b0 : if_id_i.valid ;
    assign id_ex_o.pc    = if_id_i.pc;
    assign id_ex_o.rs1_v = rs1_v;
    assign id_ex_o.rs2_v = rs2_v;
    assign id_ex_o.rd_s  = rd_s;

    // Debug signals
    assign id_ex_o.debug.instr  = instr;
    assign id_ex_o.debug.pc     = if_id_i.pc;

    `UNUSED_VAR(funct7)
endmodule
