module csrfile 
import orion_types::*;
(
    input  logic            clk_i,
    input  logic            rst_i,

    input  mem_csrf_t       mem_csrf_i,
    input  wb_csrf_t        wb_csrf_i,
    output csrf_wb_t        csrf_wb_o
);

logic [31:0] csr1_wdata;

////////////////////////////////////////////////////////////////////////////////
logic csr1_cycle_we;
logic csr1_cycleh_we;
logic csr1_instret_we;
logic csr1_instreth_we;



// Cycle counter
logic [63:0] cycle_counter;
always_ff @(posedge clk_i) begin
    if (rst_i) begin
        cycle_counter <= 64'b0;
    end else begin
        if (csr1_cycle_we) 
            cycle_counter[31:0] <= csr1_wdata;
        else if (csr1_cycleh_we) 
            cycle_counter[63:32] <= csr1_wdata;
        else
            cycle_counter <= cycle_counter + 1'b1;
    end
end

// Instruction retired counter
logic [63:0] inst_retired_counter;
always_ff @(posedge clk_i) begin
    if (rst_i) begin
        inst_retired_counter <= 64'b0;
    end else begin
        if (csr1_instret_we)
            inst_retired_counter[31:0] <= csr1_wdata;
        else if (csr1_instreth_we)
            inst_retired_counter[63:32] <= csr1_wdata;
        else if(wb_csrf_i.instr_retired)
            inst_retired_counter <= inst_retired_counter + 1'b1;
    end
end


//// READ LOGIC
logic       [11:0]  csr0_addr;
csr_ops_t           csr0_op;
logic       [31:0]  csr0_operand_val;
logic       [31:0]  csr0_rdata;
logic               csr0_wen;
logic               csr0_ren;

assign csr0_addr        = mem_csrf_i.addr;
assign csr0_op          = mem_csrf_i.op;            // Pass through for update logic 
assign csr0_operand_val = mem_csrf_i.operand;   // Pass through for update logic
assign csr0_wen         = mem_csrf_i.wen;           // Pass through for update logic
assign csr0_ren         = mem_csrf_i.ren;           // Pass through for

always_comb begin
    case(csr0_addr)
        CSR_CYCLE,CSR_MCYCLE    : csr0_rdata = cycle_counter[31:0];
        CSR_CYCLEH,CSR_MCYCLEH  : csr0_rdata = cycle_counter[63:32];
        CSR_INSTRET,CSR_MINSTRET: csr0_rdata = inst_retired_counter[31:0];
        CSR_INSTRETH,CSR_MINSTRETH: csr0_rdata = inst_retired_counter[63:32];
        default                 : csr0_rdata = 'x;
    endcase
end

////////////////////////////////////////////////////////////////////////////////
// Pipeline register

// Write logic
logic       [11:0]  csr1_addr;
csr_ops_t           csr1_op;
logic       [31:0]  csr1_operand_val;
logic       [31:0]  csr1_rdata;
logic               csr1_wen;

pipe_reg #(
    .WIDTH          ($bits(csr0_addr) + $bits(csr0_op) + $bits(csr0_operand_val) + $bits(csr0_rdata) + $bits(csr0_wen))
) csr_pipe (
    .clk_i          (clk_i),
    .rst_i          (rst_i),
    .en_i           (1'b1),
    .data_i         ({csr0_addr, csr0_op, csr0_operand_val, csr0_rdata, csr0_wen}),
    .data_o         ({csr1_addr, csr1_op, csr1_operand_val, csr1_rdata, csr1_wen})
);

always_comb begin
    case(csr1_op)
        CSR_OP_RW:  csr1_wdata = csr1_operand_val;                   // CSRRW
        CSR_OP_RS:  csr1_wdata = csr1_operand_val | csr1_rdata;      // CSRRS
        CSR_OP_RC:  csr1_wdata = ~(csr1_operand_val) & csr1_rdata;   // CSRRC
        default:    csr1_wdata = 'x;
    endcase
end

assign csr1_cycle_we    = csr1_wen && (csr1_addr == CSR_MCYCLE);
assign csr1_cycleh_we   = csr1_wen && (csr1_addr == CSR_MCYCLEH);
assign csr1_instret_we  = csr1_wen && (csr1_addr == CSR_MINSTRET);
assign csr1_instreth_we = csr1_wen && (csr1_addr == CSR_MINSTRETH);


logic illegal_instr;
// // Privilige check logic
// logic [1:0]  priv_level;
// logic [1:0]  perm; 
// assign priv_level   = csr1_addr[11:10];
// assign perm         = csr1_addr[9:8];


// logic current_priv_level = PRIV_M;
// logic required_priv_level = csr1_addr[11:10]; // CHeck this
// assign priv_mismatch = (current_priv_level < required_priv_level) ? 1'b1 : 1'b0;

always_comb begin
    illegal_instr = 1'b0;
    case(csr1_addr)
        CSR_CYCLE,CSR_INSTRET     :  if (csr1_wen) illegal_instr = 1'b1;
        CSR_CYCLEH,CSR_INSTRETH   :  if (csr1_wen) illegal_instr = 1'b1;
        CSR_MCYCLE,CSR_MINSTRET   : illegal_instr = 1'b0;
        CSR_MCYCLEH,CSR_MINSTRETH : illegal_instr = 1'b0;
        default                   : illegal_instr = 1'b1;
    endcase
end


assign csrf_wb_o.rd_v = csr1_rdata;

`UNUSED_VAR(csr0_ren);
`UNUSED_VAR(illegal_instr);
endmodule
