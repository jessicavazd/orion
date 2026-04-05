`default_nettype none

module orion_wb_adapter #(
    parameter ADDRW = 32,
    parameter DATAW = 32,
    parameter SELW  = DATAW/8,
    parameter MASKW = SELW
)(
    input  logic                 clk_i,
    input  logic                 rst_i,

    // Orion interface (Slave)
    input  logic [ADDRW-1:0]     or_addr_i,
    output logic [DATAW-1:0]     or_rdata_o,
    input  logic [DATAW-1:0]     or_wdata_i,
    input  logic [MASKW-1:0]     or_mask_i,
    input  logic                 or_we_i,
    input  logic                 or_valid_i,
    output logic                 or_ready_o,
    output logic                 or_resp_o,
    output logic                 or_err_o,

    // Wishbone interface (Master)
    output logic [ADDRW-1:0]     wbm_adr_o,
    output logic [DATAW-1:0]     wbm_dat_o,
    input  logic [DATAW-1:0]     wbm_dat_i,
    output logic                 wbm_cyc_o,
    output logic                 wbm_stb_o,
    output logic                 wbm_we_o,
    output logic [SELW-1:0]      wbm_sel_o,
    input  logic                 wbm_ack_i,
    input  logic                 wbm_err_i
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        ACTIVE = 2'b01
    } wb_state_t;

    wb_state_t state;
    logic      direct_req;
    logic      req_complete;
    logic             complete_hold_q;
    logic [ADDRW-1:0] active_addr_q;
    logic [DATAW-1:0] active_wdata_q;
    logic [MASKW-1:0] active_mask_q;
    logic             active_we_q;

    assign direct_req = (state == IDLE) && !complete_hold_q && or_valid_i;
    assign req_complete = wbm_ack_i || wbm_err_i;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state <= IDLE;
            complete_hold_q <= 1'b0;
            active_addr_q  <= '0;
            active_wdata_q <= '0;
            active_mask_q  <= '0;
            active_we_q    <= 1'b0;
        end
        else begin
            complete_hold_q <= 1'b0;

            case (state)
                IDLE: begin
                    if (direct_req && !req_complete) begin
                        active_addr_q  <= or_addr_i;
                        active_wdata_q <= or_wdata_i;
                        active_mask_q  <= or_mask_i;
                        active_we_q    <= or_we_i;
                        state <= ACTIVE;
                    end
                end
                ACTIVE: begin
                    if (req_complete) begin
                        complete_hold_q <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase

            if (direct_req && req_complete) begin
                complete_hold_q <= 1'b1;
            end
        end
    end

    assign wbm_adr_o = direct_req ? or_addr_i : active_addr_q;
    assign wbm_dat_o = direct_req ? or_wdata_i : active_wdata_q;
    assign wbm_we_o  = direct_req ? or_we_i : active_we_q;
    assign wbm_sel_o = direct_req ? or_mask_i : active_mask_q;
    assign wbm_cyc_o = (state == ACTIVE) || direct_req;
    assign wbm_stb_o = (state == ACTIVE) || direct_req;

    assign or_ready_o = (state == IDLE) && !complete_hold_q;
    assign or_resp_o  = req_complete;
    assign or_err_o   = wbm_err_i;
    assign or_rdata_o = wbm_dat_i;
endmodule
