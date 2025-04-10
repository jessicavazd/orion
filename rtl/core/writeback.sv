module writeback 
import orion_types::*;
(
    // input  logic        clk_i,
    // input  logic        rst_i,

    input  mem_wb_t     mem_wb_i,
    output wb_id_t      wb_id_o
);

assign wb_id_o.rd_we  = mem_wb_i.valid && mem_wb_i.rd_we;
assign wb_id_o.rd_s   = mem_wb_i.rd_s;
assign wb_id_o.rd_v   = mem_wb_i.rd_v;


logic               dbg_valid /* verilator public */;
logic [31:0]        dbg_instr /* verilator public */;
logic [XLEN-1:0]    dbg_pc    /* verilator public */;
assign dbg_valid    = mem_wb_i.valid;
assign dbg_instr    = mem_wb_i.debug.instr;
assign dbg_pc       = mem_wb_i.debug.pc;

endmodule
