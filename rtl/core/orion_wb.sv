`include "utils.svh"
`default_nettype none

module orion_wb
import orion_types::*;
#(
    parameter PC_RESET_ADDR = 32'h8000_0000
)(
    input  wire         clk_i,
    input  wire         rst_i,

    // Instruction port
    output logic [ADDRW-1:0]     iport_wb_adr_o,
    output logic [DATAW-1:0]     iport_wb_dat_o,
    input  logic [DATAW-1:0]     iport_wb_dat_i,
    output logic                 iport_wb_cyc_o,
    output logic                 iport_wb_stb_o,
    output logic                 iport_wb_we_o,
    output logic [SELW-1:0]      iport_wb_sel_o,
    input  logic                 iport_wb_ack_i,
    
    // Data port (for load/store)
    output logic [ADDRW-1:0]     dport_wb_adr_o,
    output logic [DATAW-1:0]     dport_wb_dat_o,
    input  logic [DATAW-1:0]     dport_wb_dat_i,
    output logic                 dport_wb_cyc_o,
    output logic                 dport_wb_stb_o,
    output logic                 dport_wb_we_o,
    output logic [SELW-1:0]      dport_wb_sel_o,
    input  logic                 dport_wb_ack_i

);

    logic [ADDRW-1:0]    imem_addr_o;
    logic [XLEN-1:0]     imem_rdata_i;
    logic                imem_valid_o;
    logic                imem_resp_i;
    logic [ADDRW-1:0]    dmem_addr_o;
    logic [XLEN-1:0]     dmem_rdata_i;
    logic [XLEN-1:0]     dmem_wdata_o;
    logic [MASKW-1:0]    dmem_mask_o;
    logic                dmem_we_o;
    logic                dmem_valid_o;
    logic                dmem_resp_i;


    orion_core #(
        .PC_RESET_ADDR (PC_RESET_ADDR)
    ) orion (
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

    orion_wb_adapter #(
        .ADDRW (ADDRW),
        .DATAW (XLEN)
    ) iport_adapter (
        .clk_i      (clk_i),
        .rst_i      (rst_i),

        .or_addr_i  (imem_addr_o),
        .or_rdata_o (imem_rdata_i),
        .or_wdata_i (32'b0),
        .or_mask_i  (4'b0),
        .or_we_i    (1'b0),
        .or_valid_i (imem_valid_o),
        .or_resp_o  (imem_resp_i),

        .wbm_adr_o  (iport_wb_adr_o),
        .wbm_dat_o  (iport_wb_dat_o),
        .wbm_dat_i  (iport_wb_dat_i),
        .wbm_cyc_o  (iport_wb_cyc_o),
        .wbm_stb_o  (iport_wb_sel_o),
        .wbm_we_o   (iport_wb_we_o),
        .wbm_sel_o  (iport_wb_sel_o),
        .wbm_ack_i  (iport_wb_ack_i)
    );


    orion_wb_adapter #(
        .ADDRW (ADDRW),
        .DATAW (XLEN)
    ) dport_adapter (
        .clk_i      (clk_i),
        .rst_i      (rst_i),

        .or_addr_i  (dmem_addr_o),
        .or_rdata_o (dmem_rdata_i),
        .or_wdata_i (dmem_wdata_o),
        .or_mask_i  (dmem_mask_o),
        .or_we_i    (dmem_we_o),
        .or_valid_i (dmem_valid_o),
        .or_resp_o  (dmem_resp_i),

        .wbm_adr_o  (dport_wb_adr_o),
        .wbm_dat_o  (doptt_wb_dat_o),
        .wbm_dat_i  (dport_wb_dat_i),
        .wbm_cyc_o  (dport_wb_cyc_o),
        .wbm_stb_o  (dport_wb_stb_o),
        .wbm_we_o   (dport_wb_we_o),
        .wbm_sel_o  (dport_wb_sel_o),
        .wbm_ack_i  (dport_wb_ack_i)
    );

endmodule
