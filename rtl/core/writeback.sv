module writeback 
import orion_types::*;
(
    // input  logic        clk_i,
    // input  logic        rst_i,

    input  mem_wb_t     mem_wb_i,
    output wb_id_t      wb_id_o,

    input  csrf_wb_t    csrf_wb_i,
    output wb_csrf_t    wb_csrf_o
);

    assign wb_id_o.rd_we  = mem_wb_i.valid && mem_wb_i.rd_we;
    assign wb_id_o.rd_s   = mem_wb_i.rd_s;
    assign wb_id_o.rd_v   = mem_wb_i.is_csr_op ? csrf_wb_i.rd_v : mem_wb_i.rd_v;


    // Interface to CSR regfile
    assign wb_csrf_o.instr_retired = mem_wb_i.valid; 


`ifndef SYNTHESIS
    // Debug signals
    logic                   dbg_valid       /* verilator public */;
    logic [31:0]            dbg_instr       /* verilator public */;
    logic [XLEN-1:0]        dbg_pc          /* verilator public */;
    logic [RF_IDX_BITS-1:0] dbg_rs1_s       /* verilator public */;
    logic [RF_IDX_BITS-1:0] dbg_rs2_s       /* verilator public */;
    logic [RF_IDX_BITS-1:0] dbg_rd_s        /* verilator public */;
    logic [XLEN-1:0]        dbg_rs1_v       /* verilator public */;
    logic [XLEN-1:0]        dbg_rs2_v       /* verilator public */;
    logic [XLEN-1:0]        dbg_rd_v        /* verilator public */;
    logic                   dbg_rd_we       /* verilator public */;
    logic [ADDRW-1:0]       dbg_mem_addr    /* verilator public */;  
    logic [MASKW-1:0]       dbg_mem_rmask   /* verilator public */;
    logic [MASKW-1:0]       dbg_mem_wmask   /* verilator public */;
    logic [XLEN-1:0]        dbg_mem_rdata   /* verilator public */;   
    logic [XLEN-1:0]        dbg_mem_wdata   /* verilator public */;  

    assign dbg_valid        = mem_wb_i.valid;
    assign dbg_instr        = mem_wb_i.debug.instr;
    assign dbg_pc           = mem_wb_i.debug.pc;
    assign dbg_rs1_s        = mem_wb_i.debug.rs1_s;
    assign dbg_rs2_s        = mem_wb_i.debug.rs2_s;
    assign dbg_rd_s         = mem_wb_i.debug.rd_s;
    assign dbg_rs1_v        = mem_wb_i.debug.rs1_v;
    assign dbg_rs2_v        = mem_wb_i.debug.rs2_v;
    assign dbg_rd_v         = wb_id_o.rd_v;
    assign dbg_rd_we        = wb_id_o.rd_we;
    assign dbg_mem_addr     = mem_wb_i.debug.mem_addr;
    assign dbg_mem_rmask    = mem_wb_i.debug.mem_rmask;
    assign dbg_mem_wmask    = mem_wb_i.debug.mem_wmask;
    assign dbg_mem_rdata    = mem_wb_i.debug.mem_rdata;
    assign dbg_mem_wdata    = mem_wb_i.debug.mem_wdata;
`endif

endmodule
