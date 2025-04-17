`include "utils.svh"
`default_nettype none

// TODO:
// deal with flush correctly in fetch stage (discard imem_resp)

module orion_core 
import orion_types::*;
(
    input logic                 clk_i,
    input logic                 rst_i,

    // I$ interface
    output logic [ADDRW-1:0]    imem_addr_o,
    input  logic [XLEN-1:0]     imem_rdata_i,
    output logic                imem_valid_o,
    input  logic                imem_resp_i,

    // D$ interface
    output logic [ADDRW-1:0]    dmem_addr_o,
    input  logic [XLEN-1:0]     dmem_rdata_i,
    output logic [XLEN-1:0]     dmem_wdata_o,
    output logic [MASKW-1:0]    dmem_mask_o,
    output logic                dmem_we_o,
    output logic                dmem_valid_o,
    input  logic                dmem_resp_i
);
    // Interfaces
    if_id_t  if_id, if_id_reg;
    id_ex_t  id_ex, id_ex_reg;
    ex_mem_t ex_mem, ex_mem_reg;
    mem_wb_t mem_wb, mem_wb_reg;

    ex_if_t  ex_if;
    ex_id_t  ex_id;
    mem_id_t mem_id;
    wb_id_t  wb_id;

    /*
        Definition of a stall in ith stage:
        - ith stage will set its output valid to 0 so that next stages take a bubble
        - 0:i-1th pipeline registers will get stalled
    */

    logic if_pc_stall;  

    logic if_id_stall;
    logic id_ex_stall;
    logic ex_mem_stall;
    logic mem_wb_stall;

    ////////////// FLUSH ////////////////////
    logic id_flush_req;
    assign id_flush_req = ex_if.jump_en;

    

    ////////////////////////////////////////////////////////////////////////////
    // Fetch stage
    fetch  fetch_stg (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .imem_addr_o    (imem_addr_o),
        .imem_rdata_i   (imem_rdata_i),
        .imem_valid_o   (imem_valid_o),
        .imem_resp_i    (imem_resp_i),

        .stall_i        (if_pc_stall),
        .ex_if_i        (ex_if),
        .if_id_o        (if_id)
    );

    pipe_reg #(
        .WIDTH          ($bits(if_id_t))
    ) if_id_pipe (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .en_i           (!if_id_stall),
        .data_i         (if_id),
        .data_o         (if_id_reg)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Decode stage
    decode decode_stg (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .flush_req      (id_flush_req),
        
        .if_id_i        (if_id_reg),
        .ex_id_i        (ex_id),
        .mem_id_i       (mem_id),
        .wb_id_i        (wb_id),

        .id_ex_o        (id_ex)
    );

    pipe_reg #(
        .WIDTH          ($bits(id_ex_t))
    ) id_ex_pipe (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .en_i           (!id_ex_stall),
        .data_i         (id_ex),
        .data_o         (id_ex_reg)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Execute stage
    execute execute_stg (
        // .clk_i          (clk_i),
        // .rst_i          (rst_i),

        // DMEM PORT
        .dmem_valid_o    (dmem_valid_o),
        .dmem_addr_o     (dmem_addr_o),
        .dmem_mask_o     (dmem_mask_o),
        .dmem_wdata_o    (dmem_wdata_o),
        .dmem_we_o       (dmem_we_o),

        .id_ex_i         (id_ex_reg),

        .ex_if_o         (ex_if),
        .ex_id_o         (ex_id),
        .ex_mem_o        (ex_mem)
    ); 

    pipe_reg #(
        .WIDTH          ($bits(ex_mem_t))
    ) ex_mem_pipe (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .en_i           (!ex_mem_stall),
        .data_i         (ex_mem),
        .data_o         (ex_mem_reg)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Memory stage
    logic mem_stall_o;

    memory memory_stg (
        // .clk_i          (clk_i),
        // .rst_i          (rst_i),

        .dmem_rdata_i   (dmem_rdata_i),
        .dmem_resp_i    (dmem_resp_i),
        .stall_o        (mem_stall_o),

        .ex_mem_i       (ex_mem_reg),

        .mem_id_o       (mem_id),
        .mem_wb_o       (mem_wb)
    );

    pipe_reg #(
        .WIDTH          ($bits(mem_wb_t))
    ) mem_wb_pipe (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .en_i           (!mem_wb_stall),
        .data_i         (mem_wb),
        .data_o         (mem_wb_reg)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Writeback stage
    writeback writeback_stg (
        // .clk_i          (clk_i),
        // .rst_i          (rst_i),

        .mem_wb_i       (mem_wb_reg),
        .wb_id_o        (wb_id)
    );


    ////////////////////////////////////////////////////////////////////////////
    // Stall logic
    assign if_pc_stall  = mem_stall_o;

    assign if_id_stall  = mem_stall_o;
    assign id_ex_stall  = mem_stall_o;
    assign ex_mem_stall = mem_stall_o;
    assign mem_wb_stall = 1'b0;

    // `UNDRIVEN_VAR(dmem_addr_o)
    // `UNDRIVEN_VAR(dmem_wdata_o)
    // `UNDRIVEN_VAR(dmem_mask_o)
    // `UNDRIVEN_VAR(dmem_we_o)
    // `UNDRIVEN_VAR(dmem_valid_o)
    // `UNUSED_VAR(dmem_resp_i)
    `UNUSED_VAR(dmem_rdata_i)
endmodule
