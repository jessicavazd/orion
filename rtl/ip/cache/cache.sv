// 2-stage pipelined cache 

// - For now: arrays are FF-based (later: SRAM)
// - Stage 1: capture CPU request + select set index for array read
// - Stage 2: tag compare + hit data mux + word extraction + resp

`include "cache.svh"

module cache #(
    parameter int ADDR_W        = `ADDR_W,
    parameter int DATA_W        = `DATA_W,
    parameter int LINE_W        = `LINE_BYTES * 8,  // in bits
    parameter int CACHE_SIZE    = `CACHE_SIZE,      // in bytes
    parameter int ASSOC         = `ASSOC
)(
    input logic                     clk,
    input logic                     rst,

    // CPU <-> Cache Interface
    cache_cpu_if #(ADDR_W, DATA_W).cache cpu_if,

    // Cache <-> Memory Interface
    cache_mem_if #(ADDR_W, LINE_W).cache  mem_if

);

// ============================================================
// Parameters 
// ============================================================

localparam int LINE_BYTES = LINE_W / 8;
localparam int NUM_SETS = CACHE_SIZE / (LINE_BYTES * ASSOC);

localparam int INDEX_W = (NUM_SETS <= 1) ? 0 : $clog2(NUM_SETS);
localparam int OFFSET_W = $clog2(LINE_BYTES); // byte offset within line
localparam int TAG_W = ADDR_W - INDEX_W - OFFSET_W;

localparam int BYTE_IN_WORD_W = $clog2(DATA_W/8);

// ============================================================
// PLRU (only for ASSOC > 1)
// ============================================================

// PLRU tree node indexing:
// Node 0: root
// Node 1: root's left child
// Node 2: root's right child

// NOTE:
// In mp_cache
//   - we stored bits that encoded "MRU direction" 
//   - at each node, 0 = left is MRU, 1 = right is MRU
//   - Victim selection - take the opposite direction of MRU bits to find LRU way

// Here we use the cleaner convention:
//   - Each PLRU node bit directly encodes which subtree is LRU-next.
//   - Victim selection = follow PLRU bits down the tree (no inversion).
//   - On access (hit/refill), we update bits along the accessed path to mark
//     the opposite subtree as LRU-next (bit = ~dir at each visited node).

generate 
    if (ASSOC > 1) begin : gen_plru
        localparam int ASSOC_W = $clog2(ASSOC); // Number of bits needed to index ways
        localparam int PLRU_BITS =  ASSOC - 1; // Number of bits needed for PLRU tree

        // PLRU bits per set
        logic [PLRU_BITS-1:0] plru_bits [0:NUM_SETS-1];
        
        // Traverse from root to leaf
        function automatic int plru_pick_victim_way(input logic [PLRU_BITS-1:0] plru_bits);
            int node;
            int way;
            begin
                node = 0;
                way = 0;
                for (int level = 0; level < ASSOC_W; level++) begin // Traverse the PLRU tree
                    if (plru_bits[node] == 1'b0) begin
                        // Go left
                        node = 2 * node + 1;
                        way = way << 1;
                    end else begin
                        // Go right
                        node = 2 * node + 2;
                        way = (way << 1) | 1;
                    end
                end
                plru_pick_victim_way = way;
            end
        endfunction


        // Go from root to leaf, updating bits along the path
        // to mark the opposite subtree as LRU-next
        // On access to left child, set bit to 1 (right is LRU-next)
        // On access to right child, set bit to 0 (left is LRU-next)
        function automatic logic [PLRU_BITS-1:0] plru_update_on_access(input logic [PLRU_BITS-1:0] plru_bits, input int accessed_way);
            logic [PLRU_BITS-1:0] new_plru_bits;
            int node;
            int dir;
            begin
                new_plru_bits = plru_bits;
                node = 0;

                for (int level = ASSOC_W - 1; level >= 0; level--) begin
                    dir = (accessed_way >> level) & 1; // 0 = left, 1 = right
                    // Update PLRU bit at current node
                    // Mark opposite subtree as LRU-next
                    new_plru_bits[node] = ~dir;

                    // Traverse to next node
                    // Move to the child corresponding to accessed_way
                    node = dir ? (2 * node + 2) : (2 * node + 1);
                end
                plru_update_on_access =  new_plru_bits;
            end
        endfunction
    end // no PLRU for direct-mapped
endgenerate

// ============================================================
// Cache arrays (FFs for now)
// ============================================================
logic [TAG_W-1:0]   tag_array   [0:NUM_SETS-1][0:ASSOC-1];
logic               valid_array [0:NUM_SETS-1][0:ASSOC-1];
logic               dirty_array [0:NUM_SETS-1][0:ASSOC-1];
logic [LINE_W-1:0]  data_array  [0:NUM_SETS-1][0:ASSOC-1];


// ============================================================
// Pipeline control
// ============================================================
logic stall;

// ============================================================
// Stage 1 regs: capture CPU req
// ============================================================
cache_req_t s1_req, s2_req;

always_ff @(posedge clk) begin
    if (rst) begin
        s1_req <= '0;
        s2_req <= '0;
    end else if (!stall) begin
        // Capture CPU request
        s1_req.valid <= cpu_if.valid;
        s1_req.addr  <= cpu_if.addr;
        s1_req.wen   <= cpu_if.wen;
        s1_req.wmask <= cpu_if.wmask;
        s1_req.wdata <= cpu_if.wdata;
        // Pipeline registers
        s2_req <= s1_req;
    end
    // else: hold current requests on stall (replay)
end

// Stage 1 index (used to read arrays)
logic [INDEX_W-1:0] s1_index;
generate
    if (INDEX_W == 0) begin
        assign s1_index = '0;
    end else begin
        assign s1_index = s1_req.addr[OFFSET_W +: INDEX_W];
    end
endgenerate

// ARRAY READ
// This models SRAM read latency: index is applied in stage 1, data is available in stage 2
// So we read arrays in stage 1 and latch outputs into stage 2 registers

logic [TAG_W-1:0]   s2_tag_array   [0:ASSOC-1];
logic               s2_valid_array [0:ASSOC-1];
logic               s2_dirty_array [0:ASSOC-1];
logic [LINE_W-1:0]  s2_data_array  [0:ASSOC-1];

always_ff @(posedge clk) begin
    if (rst) begin
        // Initialize arrays
        for (int w = 0; w < ASSOC; w++) begin
            s2_tag_array[w]   <= '0;
            s2_valid_array[w] <= 1'b0;
            s2_dirty_array[w] <= 1'b0;
            s2_data_array[w]  <= '0;
        end
    end else if (!stall) begin
        // Read arrays
        for (int w = 0; w < ASSOC; w++) begin
            s2_tag_array[w]   <= tag_array[s1_index][w];
            s2_valid_array[w] <= valid_array[s1_index][w];
            s2_dirty_array[w] <= dirty_array[s1_index][w];
            s2_data_array[w]  <= data_array[s1_index][w];
        end
    end
    // else: hold current values on stall
end

// ============================================================
// Stage 2: tag compare, hit/miss handling
// ============================================================

// Decode stage 2 address
logic [OFFSET_W-1:0] s2_offset;
logic [TAG_W-1:0]    s2_tag;

assign s2_offset    = s2_req.addr[OFFSET_W-1:0];
assign s2_tag       = s2_req.addr[ADDR_W-1 -: TAG_W];

// Tag comapre across all ways
// One hot hit way detection
logic hit;
logic [ASSOC-1:0] hit_way;

always_comb begin
    hit_way = '0;
    for (int w = 0; w < ASSOC; w++) begin
        if (s2_valid_array[w] && (s2_tag_array[w] == s2_tag)) begin
            hit_way[w] = 1'b1;
        end
    end
end

assign hit = |hit_way;

// Read the line from the hit way
logic [LINE_W-1:0] s2_read_line;
always_comb begin
    s2_read_line = '0;
    for (int w = 0; w < ASSOC; w++) begin
        if (hit_way[w]) begin
            s2_read_line = s2_data_array[w];
        end
    end
end

// Extract the requested word from the line
int unsigned word_index;
logic [DATA_W-1:0] s2_rdata;

assign word_index = s2_offset >> BYTE_IN_WORD_W;
assign s2_rdata = s2_read_line[(word_index * DATA_W) +: DATA_W];

// ============================================================
// MISS HANDLING (blocking)
//  1. Detect miss
//  2. Latch miss request
//  3. Stall pipeline & send memory request
//  4. On memory response, update cache
// ============================================================

logic miss_pending;
cache_req_t miss_req;

logic miss_now;
assign miss_now = s2_req.valid && !hit && !miss_pending;

always_ff @(posedge clk) begin
    if (rst) begin
        miss_pending <= 1'b0;
        miss_req <= '0;
    end else begin
        if (miss_pending && mem_if.mem_resp) begin
            miss_pending <= 1'b0;
            miss_req <= '0;
        end else if (miss_now) begin
            miss_pending <= 1'b1;
            miss_req <= s2_req;
        end
    end
end

// Stall pipeline when miss occurs or while miss is pending
assign stall = miss_now || miss_pending;

// Memory request generation: line aligned address
logic [ADDR_W-1:0] miss_line_addr;
assign miss_line_addr = {miss_req.addr[ADDR_W-1:OFFSET_W], {OFFSET_W{1'b0}}};

assign mem_if.mem_valid = miss_pending; // check: does memory expect mem_valid asserted the same cycle as miss detection ?
assign mem_if.mem_addr  = miss_line_addr;
assign mem_if.mem_wr    = 1'b0; // read
assign mem_if.mem_wline = '0;

// On memory response, update cache
logic [INDEX_W-1:0] miss_index;
logic [TAG_W-1:0]   miss_tag;

generate
  if (INDEX_W == 0) assign miss_index = '0;
  else assign miss_index = miss_req.addr[OFFSET_W +: INDEX_W];
endgenerate

assign miss_tag = miss_req.addr[ADDR_W-1 -: TAG_W];
    
// =============================================================
// VICTIM WAY SELECTION 
// =============================================================
// Check if there is an invalid way first
// If all ways are valid, use a PLRU policy

int invalid_way;
logic found_invalid;
always_comb begin
    found_invalid = 1'b0;
    invalid_way = 0;
    for (int w = 0; w < ASSOC; w++) begin
        if (!s2_valid_array[w] && !found_invalid) begin // First invalid way
            invalid_way = w;
            found_invalid = 1'b1;
        end
    end
end

int victim_way;
always_comb begin
    victim_way = 0; // direct-mapped default
    if (ASSOC > 1) begin
        if (found_invalid) begin
            victim_way = invalid_way; // Use first invalid way
        end else begin
            // All ways valid - use PLRU to pick victim
            victim_way = gen_plru.plru_pick_victim_way(gen_plru.plru_bits[miss_index]);
        end
    end
end

// =================================================
// Update cache arrays on memory response + PLRU update
// ================================================
always_ff @(posedge clk) begin
    if (rst) begin
        // Initialize arrays
        for (int s = 0; s < NUM_SETS; s++) begin
            for (int w = 0; w < ASSOC; w++) begin
                tag_array[s][w]   <= '0;
                valid_array[s][w] <= 1'b0;
                dirty_array[s][w] <= 1'b0;
                data_array[s][w]  <= '0;
            end
        end
        if (ASSOC > 1) begin
            for (int s = 0; s < NUM_SETS; s++) begin
                gen_plru.plru_bits[s] <= '0;
            end
        end
    end else if (miss_pending && mem_if.mem_resp) begin
        // On memory response, update cache
        // Find victim way (for now, just way 0)
        data_array [miss_index][victim_way] <= mem_if.mem_rline;
        tag_array  [miss_index][victim_way] <= miss_tag;
        valid_array[miss_index][victim_way] <= 1'b1;
        dirty_array[miss_index][victim_way] <= 1'b0;

        // Update PLRU bits
        if (ASSOC > 1)
            gen_plru.plru_bits[miss_index] <= gen_plru.plru_update_on_access(gen_plru.plru_bits[miss_index], victim_way);
    end
end

// ============================================================
// CPU RESPONSE
// ============================================================

assign cpu_if.resp  = s2_req.valid && hit;
assign cpu_if.rdata = s2_rdata;

endmodule



