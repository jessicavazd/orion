module regfile
import orion_types::*;
(
    input  logic                    clk_i,
    input  logic                    rst_i,

    input  logic [RF_IDX_BITS-1:0]  rs1_s_i,
    input  logic [RF_IDX_BITS-1:0]  rs2_s_i,
    input  logic [RF_IDX_BITS-1:0]  rd_s_i,
    
    output logic [XLEN-1:0]         rs1_v_o,
    output logic [XLEN-1:0]         rs2_v_o,
    input  logic [XLEN-1:0]         rd_v_i,

    input  logic                    we_i
);

logic [XLEN-1:0] regs [0:NUM_REGS-1] /*verilator public*/;

// Sequential write
always_ff @(posedge clk_i) begin: regfile_write
    if (rst_i) begin
        for (int i=0; i<NUM_REGS; i++) begin
            regs[i] <= {XLEN{1'b0}};
        end
    end 
    else if (we_i && (rd_s_i != {RF_IDX_BITS{1'b0}})) begin
        regs[rd_s_i] <= rd_v_i;
    end
end

// Combinatorial read
assign rs1_v_o = regs[rs1_s_i];
assign rs2_v_o = regs[rs2_s_i];

endmodule
