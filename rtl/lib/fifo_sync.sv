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
    parameter PTRW = $clog2(DEPTH);

    // The `head_ptr` and `tail_ptr` registers are `PTRW` bits wide, where `PTRW` is `$clog2(DEPTH)` + 1.
    // The extra MSB (PTRWth bit) is used to distinguish between full and empty conditions in the FIFO.
    // - When the MSBs of `head_ptr` and `tail_ptr` differ, it indicates that the FIFO has wrapped around.
    // - This is essential for correctly computing the `full_o` signal, which uses both the MSB and the lower bits.

    // The lower `PTRW-1` bits of `head_ptr` and `tail_ptr` are used to index the FIFO memory array (`mem`).
    // Masking with `[PTRW-1:0]` ensures that the memory address wraps around when the pointers exceed `DEPTH - 1`.
    // This creates a circular buffer effect, allowing the FIFO to reuse memory locations efficiently.

    reg [PTRW:0] head_ptr;
    reg [PTRW:0] tail_ptr;
    assign empty_o = (head_ptr == tail_ptr);
    assign full_o  = (head_ptr[PTRW-1:0] == tail_ptr[PTRW-1:0]) && (head_ptr[PTRW] ^ tail_ptr[PTRW]);

    reg [DATAW-1:0] mem [0: DEPTH-1];
    
    always_ff @(posedge clk_i) begin
        if(rst_i) begin
            head_ptr <= '0;
            tail_ptr <= '0;
        end 
        else begin
            case ({enq_i, deq_i})
                2'b10: begin // Enqueue only
                    if (!full_o) begin
                        mem[head_ptr[PTRW-1:0]] <= dat_i;
                        head_ptr <= head_ptr + 1;
                    end
                end
                2'b01: begin // Dequeue only
                    if (!empty_o) begin
                        tail_ptr <= tail_ptr + 1;
                    end
                end
                2'b11: begin // Enqueue and dequeue simultaneously
                    if (empty_o) begin
                        // just enqueue
                        mem[head_ptr[PTRW-1:0]] <= dat_i;
                        head_ptr <= head_ptr + 1;
                    end
                    else begin
                        // enqueue and dequeue in the same cycle (even if fifo full)
                        mem[head_ptr[PTRW-1:0]] <= dat_i;
                        head_ptr <= head_ptr + 1;
                        tail_ptr <= tail_ptr + 1;
                    end
                end
                default: ;
            endcase
        end
    end

    assign dat_o = mem[tail_ptr[PTRW-1:0]];
endmodule
