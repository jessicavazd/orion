`include "utils.svh"
`default_nettype none

module dpram #(
    parameter SIZE          = 1024, // Memory size in bytes
    parameter DATAW         = 32,   // Data width
    parameter EN_PIPE       = 1,    // Enable pipeline registers
    parameter INIT_FILE     = "",   // Memory initialization file
    parameter RESET_BUFS    = 1,    // Reset buffers

    parameter DEPTH         = SIZE/(DATAW/8),
    parameter ADDRW         = $clog2(SIZE),
    parameter MASKW         = DATAW/8
) (
    input  logic                clk_i,
    input  logic                rst_i,

    // Read only port
    input  logic [ADDRW-1:0]    p0_addr_i,
    output logic [DATAW-1:0]    p0_data_o,
    input  logic                p0_valid_i,
    output logic                p0_resp_o,
    
    // Read/Write port
    input  logic [ADDRW-1:0]    p1_addr_i,
    input  logic [DATAW-1:0]    p1_data_i,
    output logic [DATAW-1:0]    p1_data_o,
    input  logic [MASKW-1:0]    p1_mask_i,
    input  logic                p1_we_i,
    input  logic                p1_valid_i,
    output logic                p1_resp_o
);

    // Calculate memory array index
    logic [ADDRW-$clog2(DATAW/8)-1:0] p0_r_index;
    assign p0_r_index = p0_addr_i[ADDRW-1:$clog2(DATAW/8)];

    logic [ADDRW-$clog2(DATAW/8)-1:0] p1_rw_index;
    assign p1_rw_index = p1_addr_i[ADDRW-1:$clog2(DATAW/8)];

    // Memory array
    logic [DATAW-1:0] mem [0:DEPTH-1] /* verilator public */;

    // Optional memory initialization
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Sequential write (p1)
    always_ff @(posedge clk_i) begin: mem_write
        if (p1_valid_i && p1_we_i) begin
            for (integer i = 0; i < MASKW; i++) begin
                if (p1_mask_i[i]) begin
                    mem[p1_rw_index][i*8 +: 8] <= p1_data_i[i*8 +: 8];
                end
            end
        end
    end

    // Sequential/Combinational read
    generate
        if (EN_PIPE) begin: seq_read
            always_ff @(posedge clk_i) begin
                if(RESET_BUFS && rst_i) begin
                    p0_data_o  <= 0;
                    p0_resp_o  <= 0;
                    
                    p1_data_o  <= 0;
                    p1_resp_o  <= 0;
                end 
                else begin
                    p0_data_o  <= mem[p0_r_index];
                    p0_resp_o  <= p0_valid_i;

                    p1_data_o  <= mem[p1_rw_index];
                    p1_resp_o  <= p1_valid_i;
                end
            end
        end 
        else begin: comb_read
            assign p0_data_o   = mem[p0_r_index];
            assign p0_resp_o   = p0_valid_i;

            assign p1_data_o   = mem[p1_rw_index];
            assign p1_resp_o   = p1_valid_i;
        end
    endgenerate

    `UNUSED_VAR(p0_addr_i)
    `UNUSED_VAR(p1_addr_i)
endmodule
