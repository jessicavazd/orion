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

    output mem_id_t             mem_id_o,
    output mem_wb_t             mem_wb_o
);

// DMEM RESP
logic [ADDRW-1:0] mem_addr;
logic [XLEN-1:0]  mem_rdata;

assign mem_addr = ex_mem_i.rd_v;

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

logic [XLEN-1:0] rd_v;
assign rd_v = ex_mem_i.is_load ? mem_rdata : ex_mem_i.rd_v; 

// Memory stall
logic mem_stall;
assign mem_stall = ex_mem_i.valid && (ex_mem_i.is_load || ex_mem_i.is_store) && !dmem_resp_i;

assign mem_wb_o.valid  = mem_stall ? 1'b0 : ex_mem_i.valid;
assign mem_wb_o.rd_v   = rd_v;
assign mem_wb_o.rd_s   = ex_mem_i.rd_s;
assign mem_wb_o.rd_we  = ex_mem_i.rd_we;

assign stall_o = mem_stall;


// Forwarding interface to decode
assign mem_id_o.valid   = mem_wb_o.valid;
assign mem_id_o.rd_we   = mem_wb_o.rd_we;
assign mem_id_o.rd_s    = mem_wb_o.rd_s;
assign mem_id_o.rd_v    = mem_wb_o.rd_v;



`ifndef SYNTHESIS
    // Debug signals
    assign mem_wb_o.debug.instr     = ex_mem_i.debug.instr;
    assign mem_wb_o.debug.pc        = ex_mem_i.debug.pc;
    assign mem_wb_o.debug.rs1_s     = ex_mem_i.debug.rs1_s;
    assign mem_wb_o.debug.rs2_s     = ex_mem_i.debug.rs2_s;
    assign mem_wb_o.debug.rd_s      = ex_mem_i.debug.rd_s;
    assign mem_wb_o.debug.rs1_v     = ex_mem_i.debug.rs1_v;
    assign mem_wb_o.debug.rs2_v     = ex_mem_i.debug.rs2_v;
    assign mem_wb_o.debug.rd_v      = 'x;
    assign mem_wb_o.debug.rd_we     = 'x;
    assign mem_wb_o.debug.mem_addr  = ex_mem_i.debug.mem_addr;
    assign mem_wb_o.debug.mem_rmask = ex_mem_i.debug.mem_rmask;
    assign mem_wb_o.debug.mem_wmask = ex_mem_i.debug.mem_wmask;
    assign mem_wb_o.debug.mem_wdata = ex_mem_i.debug.mem_wdata;
    assign mem_wb_o.debug.mem_rdata = dmem_rdata_i;
`endif

`UNUSED_VAR(mem_addr);

endmodule
