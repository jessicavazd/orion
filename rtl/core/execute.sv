`include "utils.svh"

module execute 
import orion_types::*;
(
    // input logic         clk_i,
    // input logic         rst_i,

    // DMEM PORT
    output logic                dmem_valid_o,
    output logic [ADDRW-1:0]    dmem_addr_o,
    output logic [MASKW-1:0]    dmem_mask_o,
    output logic [XLEN-1:0]     dmem_wdata_o,
    output logic                dmem_we_o,

    input id_ex_t               id_ex_i,
    output ex_mem_t             ex_mem_o,
    output ex_if_t              ex_if_o
);

logic [31:0] a;
logic [31:0] b;
logic [31:0] alu_out;

always_comb begin
    unique case (id_ex_i.alu_sel_a)
        ALU_SEL_A_RS1   : a = id_ex_i.rs1_v;
        ALU_SEL_A_PC    : a = id_ex_i.pc;
        ALU_SEL_A_ZERO  : a = 32'b0;
        default     : a = 'bx;
    endcase
end

assign b = id_ex_i.alu_sel_b_imm ? id_ex_i.imm : id_ex_i.rs2_v;

logic signed   [31:0] as;
// logic signed   [31:0] bs;
logic unsigned [31:0] au;
logic unsigned [31:0] bu;

assign as   =   signed'(a);
// assign bs   =   signed'(b);
assign au   = unsigned'(a);
assign bu   = unsigned'(b);

always_comb begin
    case (id_ex_i.alu_op)
        ALU_OP_ADD : alu_out = au + bu;
        ALU_OP_SUB : alu_out = au - bu;
        ALU_OP_SLL : alu_out = au << bu[4:0];
        ALU_OP_XOR : alu_out = au ^ bu;
        ALU_OP_SRL : alu_out = au >> bu[4:0];
        ALU_OP_SRA : alu_out = as >>> bu[4:0]; // fixme: unsigned typecast needed?
        ALU_OP_OR  : alu_out = au | bu;
        ALU_OP_AND : alu_out = au & bu;
        default    : alu_out = 'bx;
    endcase
end

logic   [31:0]  a_cmp;
logic   [31:0]  b_cmp;
logic           cmp_out;

assign a_cmp    = id_ex_i.rs1_v;
assign b_cmp    = id_ex_i.cmp_sel_b_imm ? id_ex_i.imm : id_ex_i.rs2_v;

logic signed   [31:0] as_cmp;
logic signed   [31:0] bs_cmp;
logic unsigned [31:0] au_cmp;
logic unsigned [31:0] bu_cmp;


assign as_cmp   = signed'(a_cmp);
assign bs_cmp   = signed'(b_cmp);
assign au_cmp   = unsigned'(a_cmp);
assign bu_cmp   = unsigned'(b_cmp);

always_comb begin
    unique case (id_ex_i.cmp_op)
        CMP_OP_EQ  : cmp_out = (au_cmp == bu_cmp);
        CMP_OP_NEQ : cmp_out = (au_cmp != bu_cmp);
        CMP_OP_LT  : cmp_out = (as_cmp <  bs_cmp);
        CMP_OP_GE  : cmp_out = (as_cmp >= bs_cmp);
        CMP_OP_LTU : cmp_out = (au_cmp <  bu_cmp);
        CMP_OP_GEU : cmp_out = (au_cmp >= bu_cmp);
        default    : cmp_out = 1'bx;
    endcase
end


// MEM REQ
logic [ADDRW-1:0] mem_addr;
logic [MASKW-1:0] mem_mask;

assign mem_addr = alu_out[ADDRW-1:0];

always_comb begin
    mem_mask = '0;
    unique case (id_ex_i.ld_str_type)
        FUNCT3_LS_B, FUNCT3_LS_BU : mem_mask = 4'b0001 << mem_addr[1:0];
        FUNCT3_LS_H, FUNCT3_LS_HU : mem_mask = 4'b0011 << mem_addr[1:0];
        FUNCT3_LS_W               : mem_mask = 4'b1111;
        default    : mem_mask = 'b0;
    endcase 
end

assign dmem_addr_o   = {alu_out[ADDRW-1:2], 2'b00};
assign dmem_mask_o   = mem_mask;
assign dmem_valid_o  = id_ex_i.valid && (id_ex_i.is_load || id_ex_i.is_store); 

logic [XLEN-1:0] mem_wdata;
always_comb begin
    mem_wdata = '0;
    unique case (id_ex_i.ld_str_type)
        FUNCT3_LS_B : mem_wdata[8*mem_addr[1:0] +:8] = id_ex_i.rs2_v[7:0];
        FUNCT3_LS_H : mem_wdata[16*mem_addr[1] +:16] = id_ex_i.rs2_v[15:0];
        FUNCT3_LS_W : mem_wdata     = id_ex_i.rs2_v;
        default     : mem_wdata     = 'bx;
    endcase
end

assign dmem_wdata_o = mem_wdata;
assign dmem_we_o    = id_ex_i.is_store;

// Control instructions
assign ex_if_o.jump_en   = id_ex_i.valid && id_ex_i.is_jump && (id_ex_i.is_jump_conditional ? cmp_out : 1'b1);
assign ex_if_o.jump_addr = {alu_out[XLEN-1:1], 1'b0};


assign ex_mem_o.valid       = id_ex_i.valid;
assign ex_mem_o.rd_s        = id_ex_i.rd_s;
assign ex_mem_o.rd_we       = id_ex_i.rd_we;
assign ex_mem_o.sel_wb_mux  = id_ex_i.sel_wb_mux;
assign ex_mem_o.alu_out     = alu_out;
assign ex_mem_o.cmp_out     = cmp_out;
assign ex_mem_o.ld_str_type = id_ex_i.ld_str_type;
assign ex_mem_o.is_load     = id_ex_i.is_load;
assign ex_mem_o.is_store    = id_ex_i.is_store;

assign ex_mem_o.pc          = id_ex_i.pc;

// Debug signals
assign ex_mem_o.debug       = id_ex_i.debug;

`UNUSED_VAR(mem_addr);
endmodule
