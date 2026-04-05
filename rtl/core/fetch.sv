module fetch
import orion_types::*;
#(
    parameter PC_RESET_ADDR = 32'h8000_0000
) (
    input logic                 clk_i,
    input logic                 rst_i,

    // I$ interface
    output logic [ADDRW-1:0]    imem_addr_o,
    input  logic [DATAW-1:0]    imem_rdata_i,
    output logic                imem_valid_o,
    input  logic                imem_resp_i,
    input  logic                imem_ready_i,

    input  logic                stall_i,
    
    input  ex_if_t              ex_if_i,
    
    output if_id_t              if_id_o 
);   
    // Fetch enable: set to 1 after reset.
    // First fetch: after reset, we want to send out the first fetch request with correct addr (PC_RESET_ADDR).
    logic fetch_en;
    logic first_fetch;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            fetch_en <= 1'b0;
            first_fetch <= 1'b0;
        end
        else begin
            if(!fetch_en) begin
                fetch_en <= 1'b1;
                first_fetch <= 1'b1;
            end
            else begin
                first_fetch <= 1'b0;
            end
        end
    end

    logic discard_imem_resp;
    logic buffer_redirect_en;
    logic imem_resp;

    logic pc_stall;
    assign pc_stall = !fetch_en || !imem_ready_i || stall_i;

    
    // If we are currently stalled, we need to save the redirect request from ex stage 
    logic save_redirect;
    assign save_redirect = pc_stall && ex_if_i.jump_en;
    
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            discard_imem_resp <= 1'b0;
        end
        else begin
            if (save_redirect) begin
                discard_imem_resp <= 1'b1;
            end
            else if (discard_imem_resp && imem_resp_i) begin     // We got response from I$, discard it
                discard_imem_resp <= 1'b0;
            end
        end
    end
    assign imem_resp = imem_resp_i && !discard_imem_resp;
    
    logic redirect_pending;
    logic [XLEN-1:0] redirect_pc;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            redirect_pending <= 1'b0;
            redirect_pc <= '0;
        end
        else begin
            if (save_redirect) begin
                redirect_pending <= 1'b1;
                redirect_pc <= ex_if_i.jump_addr;
            end
            else if (!pc_stall) begin
                redirect_pending <= 1'b0;
            end
        end
    end

    logic [XLEN-1:0]  pc_next;
    always_comb begin
        if (first_fetch) begin
            pc_next = PC_RESET_ADDR;
        end
        else if (redirect_pending) begin
            pc_next = redirect_pc;
        end
        else if(ex_if_i.jump_en) begin
            pc_next = ex_if_i.jump_addr;
        end
        else begin
            pc_next = pc + 32'd4;
        end
    end

    // Send addr to I$ in current cycle
    assign imem_addr_o  = {pc_next[XLEN-1:2], 2'b00};
    assign imem_valid_o = fetch_en;

    logic [XLEN-1:0]  pc /* verilator public */;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            pc <= '0;
        end
        else begin
            if (fetch_en && !pc_stall) begin
                pc <= pc_next;
            end
        end
    end

    logic instr_valid;
    assign instr_valid    = imem_resp && !ex_if_i.jump_en;
    assign if_id_o.valid  = instr_valid;
    assign if_id_o.pc     = instr_valid ? pc : '0;
    assign if_id_o.instr  = instr_valid ? imem_rdata_i : 32'h00000013; // NOP
endmodule
