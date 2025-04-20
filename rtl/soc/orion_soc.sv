`include "utils.svh"
`default_nettype none

// `ifndef IMEM_INIT_FILE
// `define IMEM_INIT_FILE ""
// `endif

// `ifndef DMEM_INIT_FILE
// `define DMEM_INIT_FILE ""
// `endif

`ifndef MEM_INIT_FILE
`define MEM_INIT_FILE ""
`endif


module orion_soc
import orion_types::*;
import orion_soc_types::*;
(
    input logic     clk_i,
    input logic     rst_i
);

    ////////////////////////////////////////////////////////////////////////////
    // Orion Core

    logic [ADDRW-1:0]    imem_addr_o;
    logic [DATAW-1:0]    imem_rdata_i;
    logic                imem_valid_o;
    logic                imem_resp_i;

    logic [ADDRW-1:0]    dmem_addr_o;
    logic [DATAW-1:0]    dmem_rdata_i;
    logic [DATAW-1:0]    dmem_wdata_o;
    logic [MASKW-1:0]    dmem_mask_o;
    logic                dmem_we_o;
    logic                dmem_valid_o;
    logic                dmem_resp_i;

    orion_core #(
        .PC_RESET_ADDR (SOC_RESET_ADDR)
    ) core (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        
        .imem_addr_o    (imem_addr_o),
        .imem_rdata_i   (imem_rdata_i),
        .imem_valid_o   (imem_valid_o),
        .imem_resp_i    (imem_resp_i),
        
        .dmem_addr_o    (dmem_addr_o),
        .dmem_rdata_i   (dmem_rdata_i),
        .dmem_wdata_o   (dmem_wdata_o),
        .dmem_mask_o    (dmem_mask_o),
        .dmem_we_o      (dmem_we_o),
        .dmem_valid_o   (dmem_valid_o),
        .dmem_resp_i    (dmem_resp_i)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Arbiter
    logic [ADDRW-1:0] mem_addr_i;
    logic [DATAW-1:0] mem_rdata_o;
    logic [DATAW-1:0] mem_wdata_i;
    logic [MASKW-1:0] mem_mask_i;
    logic             mem_we_i;
    logic             mem_valid_i;
    logic             mem_resp_o;
    
    arbiter #(
        .NPORTS    (2),
        .ADDRW     (ADDRW),
        .DATAW     (DATAW),
        .MASKW     (MASKW)
    ) arb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        // Slave ports
        .slave_addr_i   ({ imem_addr_o,    dmem_addr_o}),
        .slave_rdata_o  ({ imem_rdata_i,   dmem_rdata_i}),
        .slave_wdata_i  ({ {DATAW{1'b0}},  dmem_wdata_o}),
        .slave_mask_i   ({ {MASKW{1'b1}},  dmem_mask_o}),
        .slave_we_i     ({ 1'b0,           dmem_we_o}),
        .slave_valid_i  ({ imem_valid_o,   dmem_valid_o}),
        .slave_resp_o   ({ imem_resp_i,    dmem_resp_i}),

        // Master port
        .master_addr_o  (mem_addr_i),
        .master_rdata_i (mem_rdata_o),
        .master_wdata_o (mem_wdata_i),
        .master_mask_o  (mem_mask_i),
        .master_we_o    (mem_we_i),
        .master_valid_o (mem_valid_i),
        .master_resp_i  (mem_resp_o)
    );
    
  
    ////////////////////////////////////////////////////////////////////////////
    // Memory

    logic [XLEN-1:0] mem_addr_aligned;
    assign mem_addr_aligned = mem_addr_i - SOC_MEM_ADDR; 
    
    assert property (@(posedge clk_i) disable iff (rst_i) 
        mem_valid_i |-> ((mem_addr_i >= SOC_MEM_ADDR) && (mem_addr_i < (SOC_MEM_ADDR + SOC_MEM_SIZE))))
        else $error("[%0t] Illegal memory access: valid=%b, addr=0x%0h", $time, mem_valid_i, mem_addr_i);

    spram #(
        .SIZE       (SOC_MEM_SIZE),
        .DATAW      (XLEN),
        .EN_PIPE    (1),
        .INIT_FILE  (`MEM_INIT_FILE)
    ) memory (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .addr_i     (mem_addr_aligned[$clog2(SOC_MEM_SIZE)-1:0]),
        .data_i     (mem_wdata_i),
        .data_o     (mem_rdata_o),
        .mask_i     (mem_mask_i),
        .we_i       (mem_we_i),
        .valid_i    (mem_valid_i),
        .resp_o     (mem_resp_o)
    );

    `UNUSED_VAR(mem_addr_aligned)
endmodule
