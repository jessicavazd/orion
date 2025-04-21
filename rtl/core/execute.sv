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

    output ex_if_t              ex_if_o,
    output ex_id_t              ex_id_o,
    output ex_mem_t             ex_mem_o
);

////////////////////////////////////////////////////////////////////////////////
// ALU
logic [31:0] alu_a;
logic [31:0] alu_b;
logic [31:0] alu_out;

// ALU:A mux
always_comb begin
    unique case (id_ex_i.alu_sel_a)
        ALU_SEL_A_RS1   : alu_a = id_ex_i.rs1_v;
        ALU_SEL_A_PC    : alu_a = id_ex_i.pc;
        ALU_SEL_A_ZERO  : alu_a = 32'b0;
        default         : alu_a = 'bx;
    endcase
end

// ALU:B mux
assign alu_b = id_ex_i.alu_sel_b_imm ? id_ex_i.imm : id_ex_i.rs2_v;

logic signed   [31:0] alu_as;
assign alu_as   =   signed'(alu_a);

always_comb begin
    case (id_ex_i.alu_op)
        ALU_OP_ADD : alu_out = alu_a  +   alu_b;
        ALU_OP_SUB : alu_out = alu_a  -   alu_b;        // FIXME: can be optimized
        ALU_OP_SLL : alu_out = alu_a  <<  alu_b[4:0];
        ALU_OP_XOR : alu_out = alu_a  ^   alu_b;
        ALU_OP_SRL : alu_out = alu_a  >>  alu_b[4:0];
        ALU_OP_SRA : alu_out = unsigned'(alu_as >>> alu_b[4:0]);   // FIXME: unsigned typecast needed?
        ALU_OP_OR  : alu_out = alu_a  |   alu_b;
        ALU_OP_AND : alu_out = alu_a  &   alu_b;
        default    : alu_out = 'bx;
    endcase
end

////////////////////////////////////////////////////////////////////////////////
// Comparator

logic   [31:0]  cmp_a;
logic   [31:0]  cmp_b;
logic           cmp_out;

assign cmp_a    = id_ex_i.rs1_v;
assign cmp_b    = id_ex_i.cmp_sel_b_imm ? id_ex_i.imm : id_ex_i.rs2_v;

logic signed   [31:0] cmp_as;
logic signed   [31:0] cmp_bs;
assign cmp_as   = signed'(cmp_a);
assign cmp_bs   = signed'(cmp_b);

always_comb begin
    unique case (id_ex_i.cmp_op)
        CMP_OP_EQ  : cmp_out = (cmp_a  == cmp_b);
        CMP_OP_NEQ : cmp_out = (cmp_a  != cmp_b);
        CMP_OP_LT  : cmp_out = (cmp_as <  cmp_bs);
        CMP_OP_GE  : cmp_out = (cmp_as >= cmp_bs);
        CMP_OP_LTU : cmp_out = (cmp_a  <  cmp_b);
        CMP_OP_GEU : cmp_out = (cmp_a  >= cmp_b);
        default    : cmp_out = 1'bx;
    endcase
end

////////////////////////////////////////////////////////////////////////////////
// Memory Request Generation

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

logic [XLEN-1:0] rd_v;
always_comb begin
    unique case (id_ex_i.ex_mux_sel)
        SEL_ALU_OUT : rd_v = alu_out;
        SEL_CMP_OUT : rd_v = {31'b0, cmp_out};
        SEL_PC_NEXT : rd_v = id_ex_i.pc + 32'd4;
        default     : rd_v = 'bx;
    endcase
end

assign ex_mem_o.valid       = id_ex_i.valid;
assign ex_mem_o.rd_s        = id_ex_i.rd_s;
assign ex_mem_o.rd_we       = id_ex_i.rd_we;
assign ex_mem_o.rd_v        = rd_v;
assign ex_mem_o.ld_str_type = id_ex_i.ld_str_type;
assign ex_mem_o.is_load     = id_ex_i.is_load;
assign ex_mem_o.is_store    = id_ex_i.is_store;

// Forwarding interface to decode
assign ex_id_o.valid        = ex_mem_o.valid;
assign ex_id_o.rd_we        = ex_mem_o.rd_we;
assign ex_id_o.rd_s         = ex_mem_o.rd_s;
assign ex_id_o.rd_v         = ex_mem_o.rd_v;
assign ex_id_o.is_load      = ex_mem_o.is_load; // For load-use hazard detection


`ifndef SYNTHESIS
    // Debug signals
    assign ex_mem_o.debug.instr     = id_ex_i.debug.instr;
    assign ex_mem_o.debug.pc        = id_ex_i.debug.pc;
    assign ex_mem_o.debug.rs1_s     = id_ex_i.debug.rs1_s;
    assign ex_mem_o.debug.rs2_s     = id_ex_i.debug.rs2_s;
    assign ex_mem_o.debug.rd_s      = id_ex_i.debug.rd_s;
    assign ex_mem_o.debug.rs1_v     = id_ex_i.debug.rs1_v;
    assign ex_mem_o.debug.rs2_v     = id_ex_i.debug.rs2_v;
    assign ex_mem_o.debug.rd_v      = 'x;
    assign ex_mem_o.debug.rd_we     = 'x;
    assign ex_mem_o.debug.mem_addr  = dmem_addr_o;      
    assign ex_mem_o.debug.mem_rmask = {MASKW{dmem_valid_o && !dmem_we_o}} & dmem_mask_o;
    assign ex_mem_o.debug.mem_wmask = {MASKW{dmem_valid_o &&  dmem_we_o}} & dmem_mask_o;
    assign ex_mem_o.debug.mem_rdata = 'x;
    assign ex_mem_o.debug.mem_wdata = dmem_wdata_o;  
`endif

`UNUSED_VAR(mem_addr);
endmodule
