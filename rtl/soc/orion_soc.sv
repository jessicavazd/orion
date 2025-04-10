`include "utils.svh"
`default_nettype none

`ifndef IMEM_INIT_FILE
`define IMEM_INIT_FILE ""
`endif

`ifndef DMEM_INIT_FILE
`define DMEM_INIT_FILE ""
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

    orion_core core (
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
    // Instruction Memory
    spram #(
        .SIZE       (SOC_IMEM_SIZE),
        .DATAW      (XLEN),
        .EN_PIPE    (1),
        .INIT_FILE  (`IMEM_INIT_FILE)
    ) imem (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .addr_i     (imem_addr_o[$clog2(SOC_IMEM_SIZE)-1:0]),
        .data_i     ('x),
        .data_o     (imem_rdata_i),
        .mask_i     (4'b1111),
        .we_i       (1'b0),
        .valid_i    (imem_valid_o),
        .resp_o     (imem_resp_i)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Data Memory
    spram #(
        .SIZE       (SOC_DMEM_SIZE),
        .DATAW      (XLEN),
        .EN_PIPE    (1),
        .INIT_FILE  (`DMEM_INIT_FILE)
    ) dmem (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .addr_i     (dmem_addr_o[$clog2(SOC_DMEM_SIZE)-1:0]),
        .data_i     (dmem_wdata_o),
        .data_o     (dmem_rdata_i),
        .mask_i     (dmem_mask_o),
        .we_i       (dmem_we_o),
        .valid_i    (dmem_valid_o),
        .resp_o     (dmem_resp_i)
    );

    `UNUSED_VAR(imem_addr_o)
    `UNUSED_VAR(dmem_addr_o)

endmodule
