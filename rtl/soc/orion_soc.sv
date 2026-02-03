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

    // Instruction port
    logic [WBADDRW-1:0]     iport_wb_adr_o;
    logic [WBDATAW-1:0]     iport_wb_dat_o;
    logic [WBDATAW-1:0]     iport_wb_dat_i;
    logic                 iport_wb_cyc_o;
    logic                 iport_wb_stb_o;
    logic                 iport_wb_we_o;
    logic [WBSELW-1:0]      iport_wb_sel_o;
    logic                 iport_wb_ack_i;
    
    // Data port (for load/store)
    logic [WBADDRW-1:0]     dport_wb_adr_o;
    logic [WBDATAW-1:0]     dport_wb_dat_o;
    logic [WBDATAW-1:0]     dport_wb_dat_i;
    logic                 dport_wb_cyc_o;
    logic                 dport_wb_stb_o;
    logic                 dport_wb_we_o;
    logic [WBSELW-1:0]      dport_wb_sel_o;
    logic                 dport_wb_ack_i;

    orion_wb #(
        .PC_RESET_ADDR (SOC_RESET_ADDR)
    ) orion_wb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .iport_wb_adr_o (iport_wb_adr_o),
        .iport_wb_dat_o (iport_wb_dat_o),
        .iport_wb_dat_i (iport_wb_dat_i),
        .iport_wb_cyc_o (iport_wb_cyc_o),
        .iport_wb_stb_o (iport_wb_stb_o),
        .iport_wb_we_o  (iport_wb_we_o),
        .iport_wb_sel_o (iport_wb_sel_o),
        .iport_wb_ack_i (iport_wb_ack_i),

        .dport_wb_adr_o (dport_wb_adr_o),
        .dport_wb_dat_o (dport_wb_dat_o),
        .dport_wb_dat_i (dport_wb_dat_i),
        .dport_wb_cyc_o (dport_wb_cyc_o),
        .dport_wb_stb_o (dport_wb_stb_o),
        .dport_wb_we_o  (dport_wb_we_o),
        .dport_wb_sel_o (dport_wb_sel_o),
        .dport_wb_ack_i (dport_wb_ack_i)
    );

    /////////////////////////////////////////////////////////////////////////////
    // CROSSBAR ( Slave: DPORT, 2 MASTERS: UART and DMEM)
    /////////////////////////////////////////////////////////////////////////////
    logic [ADDRW-1:0]     memdport_wb_adr_o;
    logic [DATAW-1:0]     memdport_wb_dat_o;
    logic [DATAW-1:0]     memdport_wb_dat_i;
    logic                 memdport_wb_cyc_o;
    logic                 memdport_wb_stb_o;
    logic                 memdport_wb_we_o;
    logic [SELW-1:0]      memdport_wb_sel_o;
    logic                 memdport_wb_ack_i;

    logic [ADDRW-1:0]     uart_wb_adr_o;
    logic [DATAW-1:0]     uart_wb_dat_o;
    logic [DATAW-1:0]     uart_wb_dat_i;
    logic                 uart_wb_cyc_o;
    logic                 uart_wb_stb_o;
    logic                 uart_wb_we_o;
    logic [SELW-1:0]      uart_wb_sel_o;
    logic                 uart_wb_ack_i;
    
    Crossbar2_wb #(
        .DATA_WIDTH (ADDRW),
        .ADDR_WIDTH (XLEN),
        .DEVICE0_ADDR (SOC_UART_BASE_ADDR), // UART
        .DEVICE0_MASK (`SIZE_TO_MASK32(SOC_UART_SIZE)),
        .DEVICE1_ADDR (SOC_MEM_BASE_ADDR), // DMEM
        .DEVICE1_MASK (`SIZE_TO_MASK32(SOC_MEM_SIZE))
    ) dport_crossbar (
        .clk_i      (clk_i),
        .rst_i      (rst_i),

        // Slave port (Orion dport)
        .wbs_adr_i      (dport_wb_adr_o),
        .wbs_dat_i      (doptt_wb_dat_o),
        .wbs_dat_o      (dport_wb_dat_i),
        .wbs_we_i       (dport_wb_we_o),
        .wbs_sel_i      (dport_wb_sel_o),
        .wbs_stb_i      (dport_wb_stb_o),
        .wbs_cyc_i      (dport_wb_cyc_o),
        .wbs_ack_o      (dport_wb_ack_iRAM_ADR_SIZE),
        /* verilator lint_off PINCONNECTEMPTY */
        .wbs_err_o      (),
        /* verilator lint_on PINCONNECTEMPTY */

        // Master port 0 (MEM)
        .wbm0_adr_o     (memdport_wb_adr_o),
        .wbm0_dat_i     (memdport_wb_dat_o),
        .wbm0_dat_o     (memdport_wb_dat_i),
        .wbm0_we_o      (memdport_wb_cyc_o),
        .wbm0_sel_o     (memdport_wb_stb_o),
        .wbm0_cyc_o     (memdport_wb_we_o),
        .wbm0_stb_o     (memdport_wb_sel_o),
        .wbm0_ack_i     (memdport_wb_ack_i),
        /* verilator lint_off PINCONNECTEMPTY */
        .wbm0_err_i     (),
        /* verilator lint_on PINCONNECTEMPTY */

        // Master port 1 (UART)
        .wbm1_adr_o     (uart_wb_adr_o),
        .wbm1_dat_i     (uart_wb_dat_o),
        .wbm1_dat_o     (uart_wb_dat_i),
        .wbm1_we_o      (uart_wb_cyc_o),
        .wbm1_sel_o     (uart_wb_stb_o),
        .wbm1_cyc_o     (uart_wb_we_o),
        .wbm1_stb_o     (uart_wb_sel_o),
        .wbm1_ack_i     (uart_wb_ack_i),
        /* verilator lint_off PINCONNECTEMPTY */
        .wbm1_err_i     ()
        /* verilator lint_on PINCONNECTEMPTY */
    );


    ////////////////////////////////////////////////////////////////////////////
    // ARBITER for memory access (IMEM and DMEM)
    ////////////////////////////////////////////////////////////////////////////
    logic [ADDRW-1:0]     mem_wb_adr_o;
    logic [DATAW-1:0]     mem_wb_dat_o;
    logic [DATAW-1:0]     mem_wb_dat_i;
    logic                 mem_wb_cyc_o;
    logic                 mem_wb_stb_o;
    logic                 mem_wb_we_o;
    logic [SELW-1:0]      mem_wb_sel_o;
    logic                 mem_wb_ack_i;

    Arbiter2_wb #(
        .ADDR_WIDTH (ADDRW),
        .DATA_WIDTH (XLEN),
        .ARB_LSB_HIGH_PRIORITY (1)
    ) arbiter (
        .clk        (clk_i),
        .rst        (rst_i),

        // Master 0 (DMEM)
        .wbm0_adr_i (memdport_wb_adr_o),
        .wbm0_dat_i (memdport_wb_dat_o),
        .wbm0_dat_o (memdport_wb_dat_i),
        .wbm0_we_i  (memdport_wb_cyc_o),
        .wbm0_sel_i (memdport_wb_stb_o),
        .wbm0_stb_i (memdport_wb_we_o),
        .wbm0_cyc_i (memdport_wb_sel_o),
        .wbm0_ack_o (memdport_wb_ack_i),

        // Master 1 (IMEM)
        .wbm1_adr_i (iport_wb_adr_o),
        .wbm1_dat_i (iport_wb_dat_o),
        .wbm1_dat_o (iport_wb_dat_i),
        .wbm1_we_i  (iport_wb_cyc_o),
        .wbm1_sel_i (iport_wb_stb_o),
        .wbm1_stb_i (iport_wb_we_o),
        .wbm1_cyc_i (iport_wb_sel_o),
        .wbm1_ack_o (iport_wb_ack_i),


        // Slave (Memory)
        .wbs_adr_o  (mem_wb_adr_o),
        .wbs_dat_o  (mem_wb_dat_o),
        .wbs_dat_i  (mem_wb_dat_i),
        .wbs_we_o   (mem_wb_cyc_o),
        .wbs_sel_o  (mem_wb_stb_o),
        .wbs_stb_o  (mem_wb_we_o),
        .wbs_cyc_o  (mem_wb_sel_o),
        .wbs_ack_i  (mem_wb_ack_i)
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
        .wb_clk_i   (wb_clk_i),
        .wb_rst_i   (wb_rst_i),

        .wb_adr_i   (mem_wb_adr_i[SOC_ADR_SIZE-1:2]),
        .wb_dat_o   (mem_wb_dat_o),
        .wb_dat_i   (mem_wb_dat_i),
        .wb_we_i    (mem_wb_we_i),
        .wb_sel_i   (mem_wb_sel_i),
        .wb_stb_i   (mem_wb_stb_i & ram_wb_cyc_i),
        .wb_ack_o   (mem_wb_ack_o)
    );


















  
    ////////////////////////////////////////////////////////////////////////////
    // Memory

    // logic [XLEN-1:0] mem_addr_aligned;
    // assign mem_addr_aligned = mem_addr_i - SOC_MEM_ADDR; 
    
    // assert property (@(posedge clk_i) disable iff (rst_i) 
    //     imem_valid_o |-> ((imem_addr_o >= SOC_MEM_ADDR) && (imem_addr_o < (SOC_MEM_ADDR + SOC_MEM_SIZE))))
    //     else $error("[%0t] Illegal memory access: valid=%b, addr=0x%0h", $time, imem_valid_o, imem_addr_o);

    // assert property (@(posedge clk_i) disable iff (rst_i) 
    //     dmem_valid_o |-> ((dmem_addr_o >= SOC_MEM_ADDR) && (dmem_addr_o < (SOC_MEM_ADDR + SOC_MEM_SIZE))))
    //     else $error("[%0t] Illegal memory access: valid=%b, addr=0x%0h", $time, dmem_valid_o, dmem_addr_o);

    // spram #(
    //     .SIZE       (SOC_MEM_SIZE),
    //     .DATAW      (XLEN),
    //     .EN_PIPE    (1),
    //     .INIT_FILE  (`MEM_INIT_FILE)
    // ) memory (
    //     .clk_i      (clk_i),
    //     .rst_i      (rst_i),
    //     .addr_i     (mem_addr_aligned[$clog2(SOC_MEM_SIZE)-1:0]),
    //     .data_i     (mem_wdata_i),
    //     .data_o     (mem_rdata_o),
    //     .mask_i     (mem_mask_i),
    //     .we_i       (mem_we_i),
    //     .valid_i    (mem_valid_i),
    //     .resp_o     (mem_resp_o)
    // );


    // dpram # (
    //     .SIZE       (SOC_MEM_SIZE),
    //     .DATAW      (XLEN),
    //     .EN_PIPE    (1),
    //     .INIT_FILE  (`MEM_INIT_FILE)
    // ) memory (
    //     .clk_i(clk_i),
    //     .rst_i(rst_i),

    //     // Read port
    //     .p0_addr_i(imem_addr_o[$clog2(SOC_MEM_SIZE)-1:0]),
    //     .p0_data_o(imem_rdata_i),
    //     .p0_valid_i(imem_valid_o),
    //     .p0_resp_o(imem_resp_i),

    //     // Read-Write port
    //     .p1_addr_i  (dmem_addr_o[$clog2(SOC_MEM_SIZE)-1:0]),
    //     .p1_data_i  (dmem_wdata_o),
    //     .p1_data_o  (dmem_rdata_i),
    //     .p1_mask_i  (dmem_mask_o),
    //     .p1_we_i    (dmem_we_o),
    //     .p1_valid_i (dmem_valid_o),
    //     .p1_resp_o  (dmem_resp_i)
    // );

    // // `UNUSED_VAR(mem_addr_aligned)
    // `UNUSED_VAR(imem_addr_o)
    // `UNUSED_VAR(dmem_addr_o)
endmodule
