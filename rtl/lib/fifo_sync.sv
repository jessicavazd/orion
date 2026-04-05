/*
    Description: A simple FIFO with synchronous read and write interfaces.
*/

`default_nettype none

module fifo_sync #(
    parameter DEPTH = 32,
    parameter DATAW = 8
)(
    input  logic             clk_i,
    input  logic             rst_i,
    input  logic [DATAW-1:0] dat_i,
    output logic [DATAW-1:0] dat_o,
    input  logic             enq_i,
    input  logic             deq_i,
    output logic             full_o,
    output logic             empty_o
);
    localparam int PTRW = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    logic [PTRW:0] head_ptr;
    logic [PTRW:0] tail_ptr;
    logic [PTRW-1:0] head_idx;
    logic [PTRW-1:0] tail_idx;
    logic [DATAW-1:0] mem [0: DEPTH-1];

    function automatic logic [PTRW:0] ptr_inc(input logic [PTRW:0] ptr);
        begin
            if (ptr[PTRW-1:0] == PTRW'(DEPTH-1)) begin
                ptr_inc[PTRW] = ~ptr[PTRW];
                ptr_inc[PTRW-1:0] = '0;
            end
            else begin
                ptr_inc = ptr + {{PTRW{1'b0}}, 1'b1};
            end
        end
    endfunction

    assign head_idx = head_ptr[PTRW-1:0];
    assign tail_idx = tail_ptr[PTRW-1:0];
    assign empty_o = (head_ptr == tail_ptr);
    assign full_o  = (head_idx == tail_idx) && (head_ptr[PTRW] ^ tail_ptr[PTRW]);
    
    always_ff @(posedge clk_i) begin
        if(rst_i) begin
            head_ptr <= '0;
            tail_ptr <= '0;
        end 
        else begin
            case ({enq_i, deq_i})
                2'b10: begin // Enqueue only
                    if (!full_o) begin
                        mem[head_idx] <= dat_i;
                        head_ptr <= ptr_inc(head_ptr);
                    end
                end
                2'b01: begin // Dequeue only
                    if (!empty_o) begin
                        tail_ptr <= ptr_inc(tail_ptr);
                    end
                end
                2'b11: begin // Enqueue and dequeue simultaneously
                    if (empty_o) begin
                        // just enqueue
                        mem[head_idx] <= dat_i;
                        head_ptr <= ptr_inc(head_ptr);
                    end
                    else begin
                        // enqueue and dequeue in the same cycle (even if fifo full)
                        mem[head_idx] <= dat_i;
                        head_ptr <= ptr_inc(head_ptr);
                        tail_ptr <= ptr_inc(tail_ptr);
                    end
                end
                default: ;
            endcase
        end
    end

    assign dat_o = mem[tail_idx];
endmodule
