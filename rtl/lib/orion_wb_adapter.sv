`default_nettype none

module orion_wb_adapter #(
    parameter ADDRW = 32,
    parameter DATAW = 32,
    parameter SELW  = DATAW/8,
    parameter MASKW = SELW
)(
    // input  logic                 clk_i,
    // input  logic                 rst_i,

    // Orion interface (Slave)
    input  logic [ADDRW-1:0]     or_addr_i,
    output logic [DATAW-1:0]     or_rdata_o,
    input  logic [DATAW-1:0]     or_wdata_i,
    input  logic [MASKW-1:0]     or_mask_i,
    input  logic                 or_we_i,
    input  logic                 or_valid_i,
    output logic                 or_resp_o,

    // Wishbone interface (Master)
    output logic [ADDRW-1:0]     wbm_adr_o,
    output logic [DATAW-1:0]     wbm_dat_o,
    input  logic [DATAW-1:0]     wbm_dat_i,
    output logic                 wbm_cyc_o,
    output logic                 wbm_stb_o,
    output logic                 wbm_we_o,
    output logic [SELW-1:0]      wbm_sel_o,
    input  logic                 wbm_ack_i
);

    assign wbm_adr_o   = or_addr_i;
    assign wbm_dat_o   = or_wdata_i;
    assign wbm_we_o    = or_we_i;
    assign wbm_sel_o   = or_mask_i;

    assign wbm_cyc_o   = or_valid_i;
    assign wbm_stb_o   = or_valid_i;

    assign or_rdata_o  = wbm_dat_i;
    assign or_resp_o   = wbm_ack_i;

endmodule
