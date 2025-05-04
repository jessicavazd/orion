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
logic [XLEN-1:0] alu_a;
logic [XLEN-1:0] alu_b;
logic [XLEN-1:0] alu_out;

// ALU:A mux
always_comb begin
    unique case (id_ex_i.alu_sel_a)
        ALU_SEL_A_RS1   : alu_a = id_ex_i.rs1_v;
        ALU_SEL_A_PC    : alu_a = id_ex_i.pc;
        ALU_SEL_A_ZERO  : alu_a = {XLEN{1'b0}};
        default         : alu_a = 'bx;
    endcase
end

// ALU:B mux
assign alu_b = id_ex_i.alu_sel_b_imm ? id_ex_i.imm : id_ex_i.rs2_v;

logic signed [XLEN-1:0] alu_as;
assign alu_as   =   signed'(alu_a);

always_comb begin
    case (id_ex_i.alu_op)
        ALU_OP_ADD : alu_out = alu_a  +   alu_b;
        ALU_OP_SUB : alu_out = alu_a  -   alu_b;        // FIXME: can be optimized
        ALU_OP_SLL : alu_out = alu_a  <<  alu_b[4:0];   // FIXME: What if XLEN is 64?
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

logic   [XLEN-1:0]  cmp_a;
logic   [XLEN-1:0]  cmp_b;
logic           cmp_out;

assign cmp_a    = id_ex_i.rs1_v;
assign cmp_b    = id_ex_i.cmp_sel_b_imm ? id_ex_i.imm : id_ex_i.rs2_v;

logic signed   [XLEN-1:0] cmp_as;
logic signed   [XLEN-1:0] cmp_bs;
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
// Multiplier/Divider

logic [2*XLEN-1:0] mul_out;
logic [XLEN-1:0] div_out;
logic use_high;
logic use_div;

generate
    if(EN_RV32M_EXT) begin: mul_ext
        // Multiplication signals
        logic [2*XLEN-1:0] mul_a;
        logic [2*XLEN-1:0] mul_b;
        logic signed [2*XLEN-1:0] mul_as;
        logic signed [2*XLEN-1:0] mul_bs;

        assign mul_a    = {{XLEN{1'b0}}, id_ex_i.rs1_v};
        assign mul_b    = {{XLEN{1'b0}}, id_ex_i.rs2_v};
        assign mul_as   = signed'({{XLEN{id_ex_i.rs1_v[XLEN-1]}}, id_ex_i.rs1_v});
        assign mul_bs   = signed'({{XLEN{id_ex_i.rs2_v[XLEN-1]}}, id_ex_i.rs2_v});


        // Division signals
        logic [XLEN-1:0] div_a;
        logic [XLEN-1:0] div_b;
        logic signed [XLEN-1:0] div_as;
        logic signed [XLEN-1:0] div_bs;

        assign div_a    = id_ex_i.rs1_v;
        assign div_b    = id_ex_i.rs2_v;
        assign div_as   = signed'(div_a);
        assign div_bs   = signed'(div_b);

        assign use_high = (id_ex_i.mul_op == MUL_OP_MULH || id_ex_i.mul_op == MUL_OP_MULHU || id_ex_i.mul_op == MUL_OP_MULHSU);
        assign use_div = (id_ex_i.mul_op == MUL_OP_DIV || id_ex_i.mul_op == MUL_OP_DIVU || id_ex_i.mul_op == MUL_OP_REM || id_ex_i.mul_op == MUL_OP_REMU);

        always_comb begin
            mul_out = '0;
            div_out = '0;
            unique case (id_ex_i.mul_op)
                MUL_OP_MUL, MUL_OP_MULH : mul_out = (mul_as * mul_bs);
                MUL_OP_MULHSU           : mul_out = (mul_as * mul_b);
                MUL_OP_MULHU            : mul_out = (mul_a  * mul_b);
                MUL_OP_DIV    : begin
                                    if (div_bs == 0) begin
                                        div_out = {XLEN{1'b1}}; // divide by zero = -1 
                                    end 
                                    else if (div_as == {1'b1, {XLEN-1{1'b0}}} && div_bs == {XLEN{1'b1}}) begin // overflow (-(2**(XLEN-1))/-1) --> 0x8000_0000/0xFFFFFFFF
                                        div_out = div_as; // overflow
                                    end
                                    else begin
                                        div_out = (div_as / div_bs);
                                    end
                                end
                MUL_OP_DIVU   : begin
                                    if (div_b == 0) begin
                                        div_out = {XLEN{1'b1}}; // divide by zero = -1
                                    end else begin
                                        div_out = (div_a  / div_b );
                                    end
                                end 
                MUL_OP_REM    : begin
                                    if (div_bs == 0) begin
                                        div_out = div_as; // rem by zero = dividend 
                                    end 
                                    else if (div_as == {1'b1, {XLEN-1{1'b0}}} && div_bs == {XLEN{1'b1}}) begin // overflow (-(2**(XLEN-1))/-1)
                                        div_out = {XLEN{1'b0}};
                                    end
                                    else begin
                                        div_out = (div_as % div_bs);
                                    end
                                end
                MUL_OP_REMU   : begin
                                    if (div_b == 0) begin
                                        div_out = div_a; // rem by zero = dividend 
                                    end else begin
                                        div_out = (div_a  % div_b );
                                    end
                                end
                default       : begin
                                    mul_out = 'x;
                                    div_out = 'x;
                                end
            endcase
        end
    end 
    else begin: no_mul_ext
        assign mul_out = 'x;
        assign div_out = 'x;
        assign use_high = 'x;
        assign use_div = 'x;
        `UNUSED_VAR(id_ex_i.mul_op);
    end
endgenerate

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
        SEL_CMP_OUT : rd_v = {{XLEN-1{1'b0}}, cmp_out};
        SEL_MUL_OUT : begin
                        if(EN_RV32M_EXT) begin
                            if (use_div) begin
                                rd_v = div_out;
                            end else begin
                                rd_v = use_high ? mul_out[2*XLEN-1:XLEN] : mul_out[XLEN-1:0];
                            end
                        end else begin
                            rd_v = 'x;
                        end
                    end
        SEL_PC_NEXT : rd_v = id_ex_i.pc + 'd4;
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
    assign ex_mem_o.debug.mem_addr  = alu_out;  // We need to send byte address to debug      
    assign ex_mem_o.debug.mem_rmask = {MASKW{dmem_valid_o && !dmem_we_o}} & dmem_mask_o;
    assign ex_mem_o.debug.mem_wmask = {MASKW{dmem_valid_o &&  dmem_we_o}} & dmem_mask_o;
    assign ex_mem_o.debug.mem_rdata = 'x;
    assign ex_mem_o.debug.mem_wdata = dmem_wdata_o;  
`endif

`UNUSED_VAR(mem_addr);
endmodule
