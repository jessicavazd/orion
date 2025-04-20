`include "utils.svh"
`default_nettype none

module spram #(
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

    input  logic [ADDRW-1:0]    addr_i,
    input  logic [DATAW-1:0]    data_i,
    output logic [DATAW-1:0]    data_o,
    input  logic [MASKW-1:0]    mask_i,
    input  logic                we_i,
    input  logic                valid_i,
    output logic                resp_o
);

    // Calculate memory array index
    logic [ADDRW-$clog2(DATAW/8)-1:0] rw_index;
    assign rw_index = addr_i[ADDRW-1:$clog2(DATAW/8)];

    // Memory array
    logic [DATAW-1:0] mem [0:DEPTH-1] /* verilator public */;

    // Optional memory initialization
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Sequential write
    always_ff @(posedge clk_i) begin: mem_write
        if (valid_i && we_i) begin
            for (integer i = 0; i < MASKW; i++) begin
                if (mask_i[i]) begin
                    mem[rw_index][i*8 +: 8] <= data_i[i*8 +: 8];
                end
            end
        end
    end

    // Sequential/Combinational read
    generate
        if (EN_PIPE) begin: seq_read
            always_ff @(posedge clk_i) begin
                if(RESET_BUFS && rst_i) begin
                    data_o  <= 0;
                    resp_o  <= 0;
                end 
                else begin
                    data_o  <= mem[rw_index];
                    resp_o  <= valid_i;
                end
            end
        end 
        else begin: comb_read
            assign data_o   = mem[rw_index];
            assign resp_o   = valid_i;
        end
    endgenerate

    `UNUSED_VAR(addr_i)
endmodule
