module fetch
import orion_types::*;
(
    input logic                 clk_i,
    input logic                 rst_i,

    // I$ interface
    output logic [ADDRW-1:0]    imem_addr_o,
    input  logic [DATAW-1:0]    imem_rdata_i,
    output logic                imem_valid_o,
    input  logic                imem_resp_i,

    input  logic                stall_i,
    
    input  ex_if_t              ex_if_i,
    
    output if_id_t              if_id_o 
);

    logic discard_imem_resp;
    assign discard_imem_resp = 1'b0;        // FIXME:

    logic imem_resp;
    assign imem_resp = imem_resp_i && !discard_imem_resp;
    
    // PC stall
    logic pc_stall;
    assign pc_stall = stall_i || !imem_resp;

    logic [XLEN-1:0]  pc_next;
    always_comb begin
        pc_next = pc + 'd4;

        if(ex_if_i.jump_en) begin
            pc_next = ex_if_i.jump_addr;
        end
    end

    // PC register
    logic [XLEN-1:0]  pc /* verilator public */;
    
    always_ff @(posedge clk_i) begin
        if(rst_i) begin
            pc <= PC_RESET_ADDR;
        end
        else begin
            if(!pc_stall)
                pc <= pc_next;
        end
    end

    // Send addr to I$ in current cycle
    assign imem_addr_o  = {pc_next[XLEN-1:2], 2'b00};
    assign imem_valid_o = 1'b1;

    assign if_id_o.pc     = pc;
    assign if_id_o.instr  = imem_rdata_i; 
    assign if_id_o.valid  = !pc_stall;

endmodule
