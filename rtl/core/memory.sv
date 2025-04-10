`include "utils.svh"

module memory 
import orion_types::*;
(
    // input  logic        clk_i,
    // input  logic        rst_i,
    
    input  logic [XLEN-1:0]     dmem_rdata_i,
    input  logic                dmem_resp_i,
    
    output logic                stall_o,

    input  ex_mem_t             ex_mem_i,
    output mem_wb_t             mem_wb_o
);

// DMEM RESP
logic [ADDRW-1:0] mem_addr;
logic [XLEN-1:0]  mem_rdata;

assign mem_addr = ex_mem_i.alu_out;

always_comb begin
    unique case (ex_mem_i.ld_str_type)
        FUNCT3_LS_B  : mem_rdata = {{24{dmem_rdata_i[7 + 8*mem_addr[1:0]]}}, dmem_rdata_i[8*mem_addr[1:0] +: 8]};
        FUNCT3_LS_BU : mem_rdata = {24'b0                                 , dmem_rdata_i[8*mem_addr[1:0] +: 8]};
        FUNCT3_LS_H  : mem_rdata = {{16{dmem_rdata_i[15 + 16*mem_addr[1]]}}, dmem_rdata_i[16*mem_addr[1]  +: 16]};
        FUNCT3_LS_HU : mem_rdata = {16'b0                                 , dmem_rdata_i[16*mem_addr[1]  +: 16]};
        FUNCT3_LS_W  : mem_rdata = dmem_rdata_i;
        default      : mem_rdata = 'bx;
    endcase
end

// Writeback MUX
logic [XLEN-1:0] rd_v_out;

always_comb begin
    unique case (ex_mem_i.sel_wb_mux)
        WB_MUX_ALU      : rd_v_out = ex_mem_i.alu_out;
        WB_MUX_CMP      : rd_v_out = {31'b0,ex_mem_i.cmp_out};
        WB_MUX_MEM      : rd_v_out = mem_rdata;
        WB_MUX_PC_NEXT  : rd_v_out = ex_mem_i.pc + 32'd4;
        default         : rd_v_out = 'bx;
    endcase
end

// Memory stall
logic mem_stall;
assign mem_stall = ex_mem_i.valid && (ex_mem_i.is_load || ex_mem_i.is_store) && !dmem_resp_i;

assign mem_wb_o.valid  = mem_stall ? 1'b0 : ex_mem_i.valid;
assign mem_wb_o.rd_v   = rd_v_out;
assign mem_wb_o.rd_s   = ex_mem_i.rd_s;
assign mem_wb_o.rd_we  = ex_mem_i.rd_we;

assign stall_o = mem_stall;

// Debug signals 
assign mem_wb_o.debug  = ex_mem_i.debug;

`UNUSED_VAR(mem_addr);


endmodule
