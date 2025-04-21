module arbiter#(
    parameter NPORTS    = 2,
    parameter ADDRW     = 32,
    parameter DATAW     = 32,

    parameter MASKW = DATAW/8
) (
    input   logic                       clk_i,
    input   logic                       rst_i,

    // stall signal
    output  logic [NPORTS-1:0]          stall_o,

    // Slave ports (bundled)
    input   logic [NPORTS*ADDRW-1:0]    slave_addr_i,
    output  logic [NPORTS*DATAW-1:0]    slave_rdata_o,
    input   logic [NPORTS*DATAW-1:0]    slave_wdata_i,
    input   logic [NPORTS*MASKW-1:0]    slave_mask_i,
    input   logic [NPORTS-1:0]          slave_we_i,
    input   logic [NPORTS-1:0]          slave_valid_i,
    output  logic [NPORTS-1:0]          slave_resp_o,

    // Master port
    output  logic [ADDRW-1:0]           master_addr_o,
    input   logic [DATAW-1:0]           master_rdata_i,
    output  logic [DATAW-1:0]           master_wdata_o,
    output  logic [MASKW-1:0]           master_mask_o,
    output  logic                       master_we_o,
    output  logic                       master_valid_o,
    input   logic                       master_resp_i
);
    localparam GRANTW = (NPORTS > 1) ? $clog2(NPORTS) : 1;

    // Request logic
    logic [NPORTS-1:0] request;
    assign request = slave_valid_i;
    
    logic request_valid;            // High if any request is valid
    assign request_valid = |request;

    logic [GRANTW-1:0] grant_comb;  // Combinatorial grant index: LSB prioritized
    always_comb begin
        grant_comb = 0;
        for (int i = 0; i < NPORTS; i++) begin
            if (request[i]) begin
                grant_comb = i[GRANTW-1:0];
                break;
            end
        end
    end
  
    logic [GRANTW-1:0]  grant_reg;  // delayed by 1 cycle (sequential)

    typedef enum  {IDLE, GRANTED} arb_state_t;
    arb_state_t arb_state;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            grant_reg <= '0;
            arb_state <= IDLE;
        end else begin
            case(arb_state)
                IDLE: begin
                    if (request_valid) begin
                        grant_reg <= grant_comb;  // take the new grant
                        arb_state <= GRANTED;
                    end
                end
                GRANTED: begin
                    if (master_valid_o && master_resp_i) begin
                        arb_state <= IDLE;  // go back to idle
                    end
                end
            endcase
        end
    end

    // Final grant signal
    logic [GRANTW-1:0] grant;
    
    // If there is a request, assign grant combinatorially otherwise maintian the previous grant
    assign grant = arb_state == IDLE && request_valid  ? grant_comb : grant_reg;


    // Grant encoded
    logic [NPORTS-1:0] grant_encoded;
    assign grant_encoded = 1 << grant;


    // Stall signal
    assign stall_o = request & ~grant_encoded;

    // Arbitration Muxes S[i] -> M
    always_comb begin
        master_addr_o   = slave_addr_i  [grant*ADDRW +:ADDRW];
        master_wdata_o  = slave_wdata_i [grant*DATAW +:DATAW];
        master_mask_o   = slave_mask_i  [grant*MASKW +:MASKW];
        master_we_o     = slave_we_i    [grant];
        master_valid_o  = slave_valid_i [grant];
    end
    
    // Arbitration Muxes M -> S[i]
    always_comb begin
        slave_resp_o          = '0;
        slave_resp_o [grant]  = master_resp_i;

        // Can provide data to all slaves, only one with response will take it
        slave_rdata_o = {NPORTS{master_rdata_i}};
    end
   
endmodule
