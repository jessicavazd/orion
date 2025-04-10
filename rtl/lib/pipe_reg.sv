/*
    Description: This module implements a pipeline register.
*/

`default_nettype none

module pipe_reg #(
    parameter WIDTH = 32,
    parameter RESETVAL = {WIDTH{1'b0}}
)(
    input  logic                clk_i,
    input  logic                rst_i,
    input  logic                en_i,
    input  logic [WIDTH-1:0]    data_i,
    output logic [WIDTH-1:0]    data_o
);
    logic [WIDTH-1:0] data /* verilator public */;

    always_ff @(posedge clk_i) begin
        if(rst_i) begin
            data <= RESETVAL;
        end 
        else if(en_i) begin
            data <= data_i;
        end
    end
    
    assign data_o = data;
endmodule
