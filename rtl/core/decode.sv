`include "utils.svh"

module decode 
import orion_types::*;
(
    input logic         clk_i,
    input logic         rst_i,
    input logic         flush_req_i,
    
    output logic        load_use_stall_req_o,

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

    logic csr_use_uimm;
    logic exception_illegal_instr;

    imm_sel_t imm_sel;

    always_comb begin 
        id_ex_o.alu_op          = ALU_OP_ADD;
        id_ex_o.cmp_op          = CMP_OP_EQ;
        id_ex_o.mul_op          = MUL_OP_MUL;
        id_ex_o.rd_we           = 1'b0;
        id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
        id_ex_o.alu_sel_b_imm   = 1'b0;
        id_ex_o.cmp_sel_b_imm   = 1'b0;
        id_ex_o.ex_mux_sel      = SEL_ALU_OUT;
        id_ex_o.ld_str_type     = funct3_load_store_t'(funct3);
        id_ex_o.is_load        = 1'b0;
        id_ex_o.is_store       = 1'b0;
        id_ex_o.is_jump        = 1'b0;
        id_ex_o.is_jump_conditional = 1'b0;
        id_ex_o.is_csr_op      = 1'b0;
        
        imm_sel                 = IMM_SEL_I;
        csr_use_uimm            = 1'b0;
        exception_illegal_instr = 1'b0;
        
        unique case (opcode) 
            OP_REG : begin
                unique casez(funct7)
                    7'b0?00000 : begin
                        // Standard ALU instructions   
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
                            default     : exception_illegal_instr = 1'b1;
                        endcase
                    end
                
                    7'b0000001 : begin
                        if(EN_RV32M_EXT) begin
                            // Multiply and divide instructions
                            id_ex_o.mul_op = mul_ops_t'(funct3);
                            id_ex_o.ex_mux_sel = SEL_MUL_OUT;
                        end 
                        else begin
                            exception_illegal_instr = 1'b1;
                        end
                    end
                
                    default : exception_illegal_instr = 1'b1;
                endcase
                id_ex_o.alu_sel_b_imm   = 1'b0;
                id_ex_o.cmp_sel_b_imm   = 1'b0;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_IMM : begin;
                unique case (funct3)
                    FUNCT3_ADD : id_ex_o.alu_op = ALU_OP_ADD;
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
                    default     : exception_illegal_instr = 1'b1;
                endcase 
                id_ex_o.alu_sel_b_imm   = 1'b1;
                id_ex_o.cmp_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_I;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_LUI: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_ZERO;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_U;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_AUIPC: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_PC;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_U;
                id_ex_o.rd_we           = 1'b1;
            end
            OP_LOAD: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_I;
                id_ex_o.rd_we           = 1'b1;
                id_ex_o.is_load         = 1'b1;
            end
            OP_STORE: begin
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_S;
                id_ex_o.rd_we           = 1'b0;
                id_ex_o.is_store        = 1'b1;
            end
            OP_JAL: begin
                // calculate target addr = pc + imm_j
                // set pc_next = target addr
                // set rd = pc + 4
                // flush 
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_PC;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_J;
                id_ex_o.rd_we           = 1'b1;
                id_ex_o.ex_mux_sel      = SEL_PC_NEXT;
                id_ex_o.is_jump         = 1'b1;
            end
            OP_JALR: begin
                // calculate target addr = rs1 + imm_i
                // set pc_next = target addr
                // set rd = pc + 4
                // flush 
                id_ex_o.alu_op          = ALU_OP_ADD;
                id_ex_o.alu_sel_a       = ALU_SEL_A_RS1;
                id_ex_o.alu_sel_b_imm   = 1'b1;
                imm_sel                 = IMM_SEL_I;
                id_ex_o.rd_we           = 1'b1;
                id_ex_o.ex_mux_sel      = SEL_PC_NEXT;
                id_ex_o.is_jump         = 1'b1;
            end
            OP_BRANCH: begin
                // calculate target addr = pc + imm_b
                // set pc_next = target addr
                // cmp rs1 & rs2 & set br_taken accordingly
                // flush 
                id_ex_o.alu_op              = ALU_OP_ADD;
                id_ex_o.alu_sel_a           = ALU_SEL_A_PC;
                id_ex_o.alu_sel_b_imm       = 1'b1;
                imm_sel                     = IMM_SEL_B;
                id_ex_o.rd_we               = 1'b0;
                id_ex_o.cmp_sel_b_imm       = 1'b0;
                id_ex_o.cmp_op              = cmp_ops_t'(funct3);
                id_ex_o.is_jump             = 1'b1;
                id_ex_o.is_jump_conditional = 1'b1;
            end
            OP_SYSTEM: begin
                unique case (funct3)
                    3'b000 : begin
                            if(imm_i[11:0] == 12'b000000000001 && rs1_s==5'b00000 && rd_s==5'b00000) begin
                                // EBREAK instruction (NOP)
                            end
                            else 
                                exception_illegal_instr = 1'b1;
                        end
                    /*
                        CSRRW:  rs1_s -> [RF] -> rs1_v -> [CSR Write|CSR read (old val)] -> [RF::rd_s]

                        CSRRS:  rs1_s -> [RF] -> rs1_v -> OR -> [CSR Write|CSR read (old val)] -> [RF::rd_s]
                                                           ^                 |
                                                           +-----------------+
                        CSRRC:  rs1_s -> [RF] -> rs1_v -> NOT -> AND -> [CSR Write|CSR read (old val)] -> [RF::rd_s]
                                                                 ^                 |
                                                                 +-----------------+
                    */
                    FUNCT3_CSRRW, FUNCT3_CSRRS, FUNCT3_CSRRC: begin
                        id_ex_o.csr_ren         = !(funct3 == FUNCT3_CSRRW && rd_s == 5'd0);
                        id_ex_o.csr_wen         = !(funct3 != FUNCT3_CSRRW && rs1_s == 5'd0);
                        id_ex_o.csr_op          = csr_ops_t'(funct3[1:0]);
                        csr_use_uimm            = 1'b0;
                        id_ex_o.rd_we           = 1'b1;
                        id_ex_o.is_csr_op       = 1'b1;
                    end

                    FUNCT3_CSRRWI, FUNCT3_CSRRSI, FUNCT3_CSRRCI: begin
                        id_ex_o.csr_ren         = !(funct3 == FUNCT3_CSRRW && rd_s == 5'd0);    // uimm is same as rs1_s
                        id_ex_o.csr_wen         = !(funct3 != FUNCT3_CSRRW && rs1_s == 5'd0);
                        id_ex_o.csr_op          = csr_ops_t'(funct3[1:0]);
                        csr_use_uimm            = 1'b1;
                        id_ex_o.rd_we           = 1'b1;
                        id_ex_o.is_csr_op       = 1'b1;
                    end
                    default : begin
                        exception_illegal_instr = 1'b1;
                    end
                endcase
            end
            default : begin
                exception_illegal_instr = 1'b1;
            end
        endcase
    end

    // illegal instruction detection
    `ifndef SYNTHESIS
    always_ff @(posedge clk_i) if(!rst_i && id_ex_o.valid && exception_illegal_instr) $warning("Illegal instruction detected: %h (PC: %h)", instr, if_id_i.pc);
    `endif
    
    
    `UNUSED_VAR(exception_illegal_instr)


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
    assign rs2_load_use_hazard = rs2_ex_fwd_en && ex_id_i.is_load;

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

    assign load_use_stall_req_o = rs1_load_use_hazard || rs2_load_use_hazard;

    assign id_ex_o.valid = (flush_req_i || load_use_stall_req_o) ? 1'b0 : if_id_i.valid ;
    assign id_ex_o.pc    = if_id_i.pc;
    assign id_ex_o.rs1_v = rs1_v_fwd;
    assign id_ex_o.rs2_v = rs2_v_fwd;
    assign id_ex_o.rd_s  = rd_s;

    // Immediate select
    always_comb begin
        case(imm_sel)
            IMM_SEL_I: id_ex_o.imm = imm_i;
            IMM_SEL_S: id_ex_o.imm = imm_s;
            IMM_SEL_B: id_ex_o.imm = imm_b;
            IMM_SEL_U: id_ex_o.imm = imm_u;
            IMM_SEL_J: id_ex_o.imm = imm_j;
            default: id_ex_o.imm = 'x;
        endcase
    end

    assign id_ex_o.csr_operand = csr_use_uimm ? {{XLEN-5{1'b0}}, rs1_s} : rs1_v_fwd;
    // NOTE: csr_addr is passed in id_ex_o.imm to execute stage to save flops


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
