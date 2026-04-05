`include "utils.svh"
`default_nettype none

// `ifndef IMEM_INIT_FILE
// `define IMEM_INIT_FILE ""
// `endif

// `ifndef DMEM_INIT_FILE
// `define DMEM_INIT_FILE ""
// `endif


// converts memory aperture size (in bytes) to 32 bit mask for wishbone crossbar
`define SIZE_TO_MASK32(sz) (-32'h1 << $clog2(sz))


`ifndef MEM_INIT_FILE
`define MEM_INIT_FILE ""
`endif


module orion_soc
import orion_types::*;
import orion_soc_types::*;
(
    input logic     clk_i,
    input logic     rst_i,
    // UART
    input logic     uart_rx_i,
    output logic    uart_tx_o
);

    ////////////////////////////////////////////////////////////////////////////
    // Orion Core

    // Instruction and Data port
    logic [WBADDRW-1:0]     core_iport_wb_adr_o;
    logic [WBDATAW-1:0]     core_iport_wb_dat_o;
    logic [WBDATAW-1:0]     core_iport_wb_dat_i;
    logic                   core_iport_wb_cyc_o;
    logic                   core_iport_wb_stb_o;
    logic                   core_iport_wb_we_o;
    logic [WBSELW-1:0]      core_iport_wb_sel_o;
    logic                   core_iport_wb_ack_i;
    logic                   core_iport_wb_err_i;
    logic [WBADDRW-1:0]     core_dport_wb_adr_o;
    logic [WBDATAW-1:0]     core_dport_wb_dat_o;
    logic [WBDATAW-1:0]     core_dport_wb_dat_i;
    logic                   core_dport_wb_cyc_o;
    logic                   core_dport_wb_stb_o;
    logic                   core_dport_wb_we_o;
    logic [WBSELW-1:0]      core_dport_wb_sel_o;
    logic                   core_dport_wb_ack_i;
    logic                   core_dport_wb_err_i;

    orion_wb #(
        .PC_RESET_ADDR (SOC_RESET_ADDR)
    ) core_wb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .iport_wb_adr_o (core_iport_wb_adr_o),
        .iport_wb_dat_o (core_iport_wb_dat_o),
        .iport_wb_dat_i (core_iport_wb_dat_i),
        .iport_wb_cyc_o (core_iport_wb_cyc_o),
        .iport_wb_stb_o (core_iport_wb_stb_o),
        .iport_wb_we_o  (core_iport_wb_we_o),
        .iport_wb_sel_o (core_iport_wb_sel_o),
        .iport_wb_ack_i (core_iport_wb_ack_i),
        .iport_wb_err_i (core_iport_wb_err_i),

        .dport_wb_adr_o (core_dport_wb_adr_o),
        .dport_wb_dat_o (core_dport_wb_dat_o),
        .dport_wb_dat_i (core_dport_wb_dat_i),
        .dport_wb_cyc_o (core_dport_wb_cyc_o),
        .dport_wb_stb_o (core_dport_wb_stb_o),
        .dport_wb_we_o  (core_dport_wb_we_o),
        .dport_wb_sel_o (core_dport_wb_sel_o),
        .dport_wb_ack_i (core_dport_wb_ack_i),
        .dport_wb_err_i (core_dport_wb_err_i)
    );

    /////////////////////////////////////////////////////////////////////////////
    // Wishbone interconnect
    // M0 = iport  -> memory only
    // M1 = dport  -> memory + UART
    /////////////////////////////////////////////////////////////////////////////
    logic [ADDRW-1:0]     mem_wb_adr_o;
    logic [DATAW-1:0]     mem_wb_dat_o;
    logic [DATAW-1:0]     mem_wb_dat_i;
    logic                 mem_wb_cyc_o;
    logic                 mem_wb_stb_o;
    logic                 mem_wb_we_o;
    logic [WBSELW-1:0]    mem_wb_sel_o;
    logic                 mem_wb_ack_i;

    logic [ADDRW-1:0]     uart_wb_adr_o;
    logic [DATAW-1:0]     uart_wb_dat_o;
    logic [DATAW-1:0]     uart_wb_dat_i;
    logic                 uart_wb_cyc_o;
    logic                 uart_wb_stb_o;
    logic                 uart_wb_we_o;
    logic [WBSELW-1:0]    uart_wb_sel_o;
    logic                 uart_wb_ack_i;

    Xbar2x2_wb #(
        .DATA_WIDTH             (XLEN),
        .ADDR_WIDTH             (ADDRW),
        .SLAVE0_ADDR            (SOC_MEM_BASE_ADDR),
        .SLAVE0_MASK            (`SIZE_TO_MASK32(SOC_MEM_SIZE)),
        .SLAVE1_ADDR            (SOC_UART_BASE_ADDR),
        .SLAVE1_MASK            (`SIZE_TO_MASK32(SOC_UART_SIZE))
    ) xbar (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),

        // Master 0: instruction port, memory only
        .wbm0_adr_i             (core_iport_wb_adr_o),
        .wbm0_dat_i             (core_iport_wb_dat_o),
        .wbm0_dat_o             (core_iport_wb_dat_i),
        .wbm0_we_i              (core_iport_wb_we_o),
        .wbm0_sel_i             (core_iport_wb_sel_o),
        .wbm0_stb_i             (core_iport_wb_stb_o),
        .wbm0_cyc_i             (core_iport_wb_cyc_o),
        .wbm0_ack_o             (core_iport_wb_ack_i),
        .wbm0_err_o             (core_iport_wb_err_i),

        // Master 1: data port, memory + UART
        .wbm1_adr_i             (core_dport_wb_adr_o),
        .wbm1_dat_i             (core_dport_wb_dat_o),
        .wbm1_dat_o             (core_dport_wb_dat_i),
        .wbm1_we_i              (core_dport_wb_we_o),
        .wbm1_sel_i             (core_dport_wb_sel_o),
        .wbm1_stb_i             (core_dport_wb_stb_o),
        .wbm1_cyc_i             (core_dport_wb_cyc_o),
        .wbm1_ack_o             (core_dport_wb_ack_i),
        .wbm1_err_o             (core_dport_wb_err_i),

        // Slave 0: memory
        .wbs0_adr_o             (mem_wb_adr_o),
        .wbs0_dat_o             (mem_wb_dat_o),
        .wbs0_dat_i             (mem_wb_dat_i),
        .wbs0_we_o              (mem_wb_we_o),
        .wbs0_sel_o             (mem_wb_sel_o),
        .wbs0_stb_o             (mem_wb_stb_o),
        .wbs0_cyc_o             (mem_wb_cyc_o),
        .wbs0_ack_i             (mem_wb_ack_i),
        .wbs0_err_i             (1'b0),

        // Slave 1: UART
        .wbs1_adr_o             (uart_wb_adr_o),
        .wbs1_dat_o             (uart_wb_dat_o),
        .wbs1_dat_i             (uart_wb_dat_i),
        .wbs1_we_o              (uart_wb_we_o),
        .wbs1_sel_o             (uart_wb_sel_o),
        .wbs1_stb_o             (uart_wb_stb_o),
        .wbs1_cyc_o             (uart_wb_cyc_o),
        .wbs1_ack_i             (uart_wb_ack_i),
        .wbs1_err_i             (1'b0)
    );


    ////////////////////////////////////////////////////////////////////////////
    // UART
    ///////////////////////////////////////////////////////////////////////////
    
    uart_wb # () uart(
        .wb_clk_i   (clk_i),
        .wb_rst_i   (rst_i),

        .wb_adr_i   (uart_wb_adr_o[3:2]),
        .wb_dat_i   (uart_wb_dat_o),
        .wb_dat_o   (uart_wb_dat_i),
        .wb_we_i    (uart_wb_we_o),
        .wb_sel_i   (uart_wb_sel_o),
        .wb_stb_i   (uart_wb_stb_o & uart_wb_cyc_o),
        .wb_ack_o   (uart_wb_ack_i),

        // UART signals
        .rx_i       (uart_rx_i),
        .tx_o       (uart_tx_o)
    );



    ////////////////////////////////////////////////////////////////////////////
    // MEMORY
    ////////////////////////////////////////////////////////////////////////////
    
    parameter SOC_ADR_SIZE = $clog2(SOC_MEM_SIZE);

    spram_wb #(
        .ADDR_WIDTH(SOC_ADR_SIZE),
        .MEM_FILE(`MEM_INIT_FILE)
    ) ram (
        .wb_clk_i   (clk_i),
        .wb_rst_i   (rst_i),

        .wb_adr_i   (mem_wb_adr_o[SOC_ADR_SIZE-1:2]),
        .wb_dat_o   (mem_wb_dat_i),
        .wb_dat_i   (mem_wb_dat_o),
        .wb_we_i    (mem_wb_we_o),
        .wb_sel_i   (mem_wb_sel_o),
        .wb_stb_i   (mem_wb_stb_o & mem_wb_cyc_o),
        .wb_ack_o   (mem_wb_ack_i)
    );
endmodule
