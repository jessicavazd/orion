`include "utils.svh"

module decode 
import orion_types::*;
(
    input logic         clk_i,
    input logic         rst_i,
    input logic         flush_req,

    input if_id_t       if_id_i,
    input ex_id_t       ex_id_i,
    input mem_id_t      mem_id_i,
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

    always_comb begin 
        id_ex_o.alu_op          = ALU_OP_ADD;
        id_ex_o.cmp_op          = CMP_OP_EQ;
        id_ex_o.rd_we           = 1'b0;
        id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
        id_ex_o.alu_sel_b_imm   = 1'b0;
        id_ex_o.cmp_sel_b_imm   = 1'b0;
        id_ex_o.ex_mux_sel      = SEL_ALU_OUT;
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
                                    id_ex_o.ex_mux_sel  = SEL_CMP_OUT;
                                end
                    FUNCT3_SLTU : begin
                                    id_ex_o.cmp_op      = CMP_OP_LTU;
                                    id_ex_o.ex_mux_sel  = SEL_CMP_OUT;
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
                                    id_ex_o.ex_mux_sel  = SEL_CMP_OUT;
                                end
                    FUNCT3_SLTU : begin
                                    id_ex_o.cmp_op      = CMP_OP_LTU;
                                    id_ex_o.ex_mux_sel  = SEL_CMP_OUT;
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
                id_ex_o.is_load         = 1'b1;
            end
            OP_STORE: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.imm             = imm_s;
                id_ex_o.rd_we           = 1'b0;
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
                id_ex_o.ex_mux_sel      = SEL_PC_NEXT;
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
                id_ex_o.ex_mux_sel      = SEL_PC_NEXT;
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

    ////////////////////////////////////////////////////////////////////////////
    // Register File

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

    ////////////////////////////////////////////////////////////////////////////
    // Forwarding logic

    logic rs1_ex_fwd_en;
    logic rs2_ex_fwd_en;
    logic rs1_mem_fwd_en;
    logic rs2_mem_fwd_en;
    assign rs1_ex_fwd_en    = ex_id_i.valid && ex_id_i.rd_we && (rs1_s != 5'b0) && (rs1_s == ex_id_i.rd_s);
    assign rs2_ex_fwd_en    = ex_id_i.valid && ex_id_i.rd_we && (rs2_s != 5'b0) && (rs2_s == ex_id_i.rd_s);
    assign rs1_mem_fwd_en   = mem_id_i.valid && mem_id_i.rd_we && (rs1_s != 5'b0) && (rs1_s == mem_id_i.rd_s);
    assign rs2_mem_fwd_en   = mem_id_i.valid && mem_id_i.rd_we && (rs2_s != 5'b0) && (rs2_s == mem_id_i.rd_s);

    // Load use hazard detection
    // - occurs when forwarding is possible from the EX stage to the ID stage
    //   But instruction in EX stage is a load instruction, therefore load data ins not available yet
    logic rs1_load_use_hazard;
    logic rs2_load_use_hazard;
    assign rs1_load_use_hazard = rs1_ex_fwd_en && ex_id_i.is_load;
    assign rs2_load_use_hazard = rs1_ex_fwd_en && ex_id_i.is_load;

    // Rs1_v forwarding mux
    logic [XLEN-1:0] rs1_v_fwd;
    always_comb begin
        rs1_v_fwd = rs1_v;  // default
        if(!rs1_load_use_hazard) begin
            if (rs1_ex_fwd_en)
                rs1_v_fwd = ex_id_i.rd_v;
            else if (rs1_mem_fwd_en)
                rs1_v_fwd = mem_id_i.rd_v;
            else 
                rs1_v_fwd = rs1_v;
        end
    end

    // Rs2_v forwarding mux
    logic [XLEN-1:0] rs2_v_fwd;
    always_comb begin
        rs2_v_fwd = rs2_v;  // default
        if(!rs2_load_use_hazard) begin
            if (rs2_ex_fwd_en)
                rs2_v_fwd = ex_id_i.rd_v;
            else if (rs2_mem_fwd_en)
                rs2_v_fwd = mem_id_i.rd_v;
            else 
                rs2_v_fwd = rs2_v;
        end
    end

    assign id_ex_o.valid = flush_req ? 1'b0 : if_id_i.valid ;
    assign id_ex_o.pc    = if_id_i.pc;
    assign id_ex_o.rs1_v = rs1_v_fwd;
    assign id_ex_o.rs2_v = rs2_v_fwd;
    assign id_ex_o.rd_s  = rd_s;

`ifndef SYNTHESIS
    // Debug signals
    assign id_ex_o.debug.instr     = instr;
    assign id_ex_o.debug.pc        = if_id_i.pc;
    assign id_ex_o.debug.rs1_s     = rs1_s;
    assign id_ex_o.debug.rs2_s     = rs2_s;
    assign id_ex_o.debug.rd_s      = rd_s;
    assign id_ex_o.debug.rs1_v     = rs1_v_fwd;
    assign id_ex_o.debug.rs2_v     = rs2_v_fwd;
    assign id_ex_o.debug.rd_v      = 'x;
    assign id_ex_o.debug.rd_we     = 'x;
    assign id_ex_o.debug.mem_addr  = 'x;      
    assign id_ex_o.debug.mem_rmask = 'x; 
    assign id_ex_o.debug.mem_wmask = 'x;        
    assign id_ex_o.debug.mem_rdata = 'x;      
    assign id_ex_o.debug.mem_wdata = 'x;
`endif

    `UNUSED_VAR(funct7)
endmodule
