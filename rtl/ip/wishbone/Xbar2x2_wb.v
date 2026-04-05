
module Xbar2x2_wb_Priority_encoder #(
    parameter WIDTH = 8,
    parameter LSB_HIGH_PRIORITY = 0,
    parameter ENC_WIDTH = (WIDTH <= 1) ? 1 : $clog2(WIDTH)
) (
    input  wire [WIDTH-1:0]         inp_i,
    output reg  [ENC_WIDTH-1:0]     enc_o,
    output reg  [WIDTH-1:0]         onehot_o,
    output reg                      valid_o
);
    integer i;
    always @(*) begin
        valid_o  = 1'b0;
        enc_o    = 0;
        onehot_o = {WIDTH{1'b0}};
        if (LSB_HIGH_PRIORITY) begin
            for (i = WIDTH-1; i >= 0; i = i - 1)
                if (inp_i[i]) begin
                    valid_o = 1'b1;
                    enc_o   = i[ENC_WIDTH-1:0];
                end
        end else begin
            for (i = 0; i < WIDTH; i = i + 1)
                if (inp_i[i]) begin
                    valid_o = 1'b1;
                    enc_o   = i[ENC_WIDTH-1:0];
                end
        end
        if (valid_o)
            onehot_o[enc_o] = 1'b1;
    end
endmodule // Xbar2x2_wb_Priority_encoder


// Arbiter Xbar2x2_wb_Arbiter2: 2 request ports
module Xbar2x2_wb_Arbiter2 #(
    parameter ARB_TYPE_ROUND_ROBIN  = 0,  // 0=fixed-priority, 1=round-robin
    parameter ARB_LSB_HIGH_PRIORITY = 0       // 1=port0 highest in fixed-priority mode
)(
    input  wire             clk_i,
    input  wire             rst_i,
    input  wire [1:0] request_i,
    output wire [1:0] grant_o,
    output wire             grant_valid_o
);
    // In round-robin mode use LSB=1 so arbitration cycles 0,1,...,N-1,0,...
    // In fixed-priority mode ARB_LSB_HIGH_PRIORITY selects which end wins.
    localparam PE_LSB_PRIO = ARB_TYPE_ROUND_ROBIN ? 1 : ARB_LSB_HIGH_PRIORITY;

    reg [1:0] grant_reg       = 2'b0;
    reg                          grant_valid_reg  = 1'b0;
    reg [1:0] mask_reg         = 2'b0;
    reg [1:0] grant_next, mask_next;
    reg                          grant_valid_next;

    assign grant_o       = grant_reg;
    assign grant_valid_o = grant_valid_reg;

    wire [0:0] req_idx;
    wire [1:0] req_mask;
    wire req_valid;

    Xbar2x2_wb_Priority_encoder #(
        .WIDTH(2),
        .LSB_HIGH_PRIORITY(PE_LSB_PRIO)
    ) pe_unmasked (
        .inp_i(request_i),
        .enc_o(req_idx),
        .onehot_o(req_mask),
        .valid_o(req_valid)
    );

    // Masked PE for round-robin: request & mask_reg exposes only ports after last grant
    wire [0:0] masked_req_idx;
    wire [1:0] masked_req_mask;
    wire masked_req_valid;

    Xbar2x2_wb_Priority_encoder #(
        .WIDTH(2),
        .LSB_HIGH_PRIORITY(PE_LSB_PRIO)
    ) pe_masked (
        .inp_i(request_i & mask_reg),
        .enc_o(masked_req_idx),
        .onehot_o(masked_req_mask),
        .valid_o(masked_req_valid)
    );

    always @(*) begin
        grant_next       = 2'b0;
        grant_valid_next = 1'b0;
        mask_next        = mask_reg;

        if (|(grant_reg & request_i)) begin
            // Hold: current grantee still has CYC asserted
            grant_next       = grant_reg;
            grant_valid_next = grant_valid_reg;
        end else if (req_valid) begin
            if (ARB_TYPE_ROUND_ROBIN) begin
                if (masked_req_valid) begin
                    grant_next       = masked_req_mask;
                    grant_valid_next = 1'b1;
                    // Advance mask: expose ports above masked_req_idx for next round
                    // ~((1 << (idx+1)) - 1) sets bits idx+1..N-1
                    mask_next = ~(( 2'b1 << (masked_req_idx + 1)) - 2'b1);
                end else begin
                    // Mask exhausted: wrap around, grant unmasked winner
                    grant_next       = req_mask;
                    grant_valid_next = 1'b1;
                    mask_next = ~(( 2'b1 << (req_idx + 1)) - 2'b1);
                end
            end else begin
                grant_next       = req_mask;
                grant_valid_next = 1'b1;
            end
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            grant_reg       <= 2'b0;
            grant_valid_reg <= 1'b0;
            mask_reg        <= 2'b0;
        end else begin
            grant_reg       <= grant_next;
            grant_valid_reg <= grant_valid_next;
            mask_reg        <= mask_next;
        end
    end

endmodule // Xbar2x2_wb_Arbiter2

// Wishbone mux Xbar2x2_wb_Arbiter2_wb: 2 masters -> 1 slave
module Xbar2x2_wb_Arbiter2_wb #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter SELECT_WIDTH = (DATA_WIDTH/8),
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    parameter ARB_M0_HIGH_PRIORITY = 0
)(
    input  wire             clk_i,
    input  wire             rst_i,

    
    // Master 0
    input  wire [ADDR_WIDTH-1:0]   wbm0_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm0_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm0_dat_o,
    input  wire                    wbm0_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm0_sel_i,
    input  wire                    wbm0_stb_i,
    input  wire                    wbm0_cyc_i,
    output wire                    wbm0_ack_o,
    output wire                    wbm0_err_o,
    
    // Master 1
    input  wire [ADDR_WIDTH-1:0]   wbm1_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm1_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm1_dat_o,
    input  wire                    wbm1_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm1_sel_i,
    input  wire                    wbm1_stb_i,
    input  wire                    wbm1_cyc_i,
    output wire                    wbm1_ack_o,
    output wire                    wbm1_err_o,
    

    // Slave
    output wire [ADDR_WIDTH-1:0]   wbs_adr_o,
    input  wire [DATA_WIDTH-1:0]   wbs_dat_i,
    output wire [DATA_WIDTH-1:0]   wbs_dat_o,
    output wire                    wbs_we_o,
    output wire [SELECT_WIDTH-1:0] wbs_sel_o,
    output wire                    wbs_stb_o,
    output wire                    wbs_cyc_o,
    input  wire                    wbs_ack_i,
    input  wire                    wbs_err_i
);
    wire [1:0] request;
    wire [1:0] grant;
    wire arb_grant_valid;

    
    assign request[0] = wbm0_cyc_i;
    wire wbm0_grant = grant[0] && arb_grant_valid;
    
    assign request[1] = wbm1_cyc_i;
    wire wbm1_grant = grant[1] && arb_grant_valid;
    

    Xbar2x2_wb_Arbiter2 #(
        .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
        .ARB_LSB_HIGH_PRIORITY(ARB_M0_HIGH_PRIORITY)
    ) arb_inst (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .request_i(request),
        .grant_o(grant),
        .grant_valid_o(arb_grant_valid)
    );

    assign wbs_adr_o =
        wbm0_grant ? wbm0_adr_i :
        wbm1_grant ? wbm1_adr_i :
        '0;

    assign wbs_dat_o =
        wbm0_grant ? wbm0_dat_i :
        wbm1_grant ? wbm1_dat_i :
        '0;

    assign wbs_we_o =
        wbm0_grant ? wbm0_we_i :
        wbm1_grant ? wbm1_we_i :
        1'b0;

    assign wbs_sel_o =
        wbm0_grant ? wbm0_sel_i :
        wbm1_grant ? wbm1_sel_i :
        '0;

    assign wbs_stb_o =
        wbm0_grant ? wbm0_stb_i :
        wbm1_grant ? wbm1_stb_i :
        1'b0;

    assign wbs_cyc_o = arb_grant_valid;

    
    assign wbm0_dat_o = wbs_dat_i;
    assign wbm0_ack_o = wbs_ack_i && wbm0_grant;
    assign wbm0_err_o = wbs_err_i && wbm0_grant;
    
    assign wbm1_dat_o = wbs_dat_i;
    assign wbm1_ack_o = wbs_ack_i && wbm1_grant;
    assign wbm1_err_o = wbs_err_i && wbm1_grant;
    

endmodule

// Wishbone crossbar Xbar2x2_wb: 2 master(s) x 2 slave(s)
module Xbar2x2_wb #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter SELECT_WIDTH = (DATA_WIDTH/8),
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    parameter ARB_M0_HIGH_PRIORITY = 0,
    parameter SLAVE0_ADDR = 32'h00000000,
    parameter SLAVE0_MASK = 32'h00000000,
    parameter SLAVE1_ADDR = 32'h00000000,
    parameter SLAVE1_MASK = 32'h00000000
)(
    input  wire                    clk_i,
    input  wire                    rst_i,
    
    // Master 0
    input  wire [ADDR_WIDTH-1:0]   wbm0_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm0_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm0_dat_o,
    input  wire                    wbm0_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm0_sel_i,
    input  wire                    wbm0_stb_i,
    input  wire                    wbm0_cyc_i,
    output wire                    wbm0_ack_o,
    output wire                    wbm0_err_o,
    
    // Master 1
    input  wire [ADDR_WIDTH-1:0]   wbm1_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm1_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm1_dat_o,
    input  wire                    wbm1_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm1_sel_i,
    input  wire                    wbm1_stb_i,
    input  wire                    wbm1_cyc_i,
    output wire                    wbm1_ack_o,
    output wire                    wbm1_err_o,
    
    
    // Slave 0
    output wire [ADDR_WIDTH-1:0]   wbs0_adr_o,
    output wire [DATA_WIDTH-1:0]   wbs0_dat_o,
    input  wire [DATA_WIDTH-1:0]   wbs0_dat_i,
    output wire                    wbs0_we_o,
    output wire [SELECT_WIDTH-1:0] wbs0_sel_o,
    output wire                    wbs0_stb_o,
    output wire                    wbs0_cyc_o,
    input  wire                    wbs0_ack_i,
    input  wire                    wbs0_err_i,
    
    // Slave 1
    output wire [ADDR_WIDTH-1:0]   wbs1_adr_o,
    output wire [DATA_WIDTH-1:0]   wbs1_dat_o,
    input  wire [DATA_WIDTH-1:0]   wbs1_dat_i,
    output wire                    wbs1_we_o,
    output wire [SELECT_WIDTH-1:0] wbs1_sel_o,
    output wire                    wbs1_stb_o,
    output wire                    wbs1_cyc_o,
    input  wire                    wbs1_ack_i,
    input  wire                    wbs1_err_i
    
);

    // Address decode
    
    
    wire m0_sel_s0 = wbm0_cyc_i && ((wbm0_adr_i & SLAVE0_MASK) == (SLAVE0_ADDR & SLAVE0_MASK));
    
    
    
    wire m1_sel_s0 = wbm1_cyc_i && ((wbm1_adr_i & SLAVE0_MASK) == (SLAVE0_ADDR & SLAVE0_MASK));
    
    wire m1_sel_s1 = wbm1_cyc_i && ((wbm1_adr_i & SLAVE1_MASK) == (SLAVE1_ADDR & SLAVE1_MASK));
    
    

    // Per-slave arbitration and muxing
    
    // Slave 0
    
    
    
    wire [DATA_WIDTH-1:0] s0_wbm0_dat;
    wire s0_wbm0_ack;
    wire s0_wbm0_err;
    
    wire [DATA_WIDTH-1:0] s0_wbm1_dat;
    wire s0_wbm1_ack;
    wire s0_wbm1_err;
    

    Xbar2x2_wb_Arbiter2_wb #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SELECT_WIDTH(SELECT_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
        .ARB_M0_HIGH_PRIORITY(ARB_M0_HIGH_PRIORITY)
    ) s0_mux (
        .clk_i(clk_i),
        .rst_i(rst_i),
        
        .wbm0_adr_i(wbm0_adr_i),
        .wbm0_dat_i(wbm0_dat_i),
        .wbm0_dat_o(s0_wbm0_dat),
        .wbm0_we_i(wbm0_we_i),
        .wbm0_sel_i(wbm0_sel_i),
        .wbm0_stb_i(wbm0_stb_i),
        .wbm0_cyc_i(m0_sel_s0),
        .wbm0_ack_o(s0_wbm0_ack),
        .wbm0_err_o(s0_wbm0_err),
        
        .wbm1_adr_i(wbm1_adr_i),
        .wbm1_dat_i(wbm1_dat_i),
        .wbm1_dat_o(s0_wbm1_dat),
        .wbm1_we_i(wbm1_we_i),
        .wbm1_sel_i(wbm1_sel_i),
        .wbm1_stb_i(wbm1_stb_i),
        .wbm1_cyc_i(m1_sel_s0),
        .wbm1_ack_o(s0_wbm1_ack),
        .wbm1_err_o(s0_wbm1_err),
        
        .wbs_adr_o(wbs0_adr_o),
        .wbs_dat_i(wbs0_dat_i),
        .wbs_dat_o(wbs0_dat_o),
        .wbs_we_o(wbs0_we_o),
        .wbs_sel_o(wbs0_sel_o),
        .wbs_stb_o(wbs0_stb_o),
        .wbs_cyc_o(wbs0_cyc_o),
        .wbs_ack_i(wbs0_ack_i),
        .wbs_err_i(wbs0_err_i)
    );
    
    
    // Slave 1
    
    
    assign wbs1_adr_o = wbm1_adr_i;
    assign wbs1_dat_o = wbm1_dat_i;
    assign wbs1_we_o = wbm1_we_i;
    assign wbs1_sel_o = wbm1_sel_i;
    assign wbs1_stb_o = wbm1_stb_i && m1_sel_s1;
    assign wbs1_cyc_o = m1_sel_s1;
    
    

    // Per-master response routing
    
    assign wbm0_ack_o =
    s0_wbm0_ack;

assign wbm0_dat_o =
    ({DATA_WIDTH{m0_sel_s0}} & s0_wbm0_dat);

assign wbm0_err_o = wbm0_cyc_i & (
    !(m0_sel_s0)
    | s0_wbm0_err
);

    
    assign wbm1_ack_o =
    s0_wbm1_ack |
    (m1_sel_s1 & wbs1_ack_i);

assign wbm1_dat_o =
    ({DATA_WIDTH{m1_sel_s0}} & s0_wbm1_dat) |
    ({DATA_WIDTH{m1_sel_s1}} & wbs1_dat_i);

assign wbm1_err_o = wbm1_cyc_i & (
    !(m1_sel_s0 | m1_sel_s1)
    | s0_wbm1_err
    | (m1_sel_s1 & wbs1_err_i)
);

    
endmodule
