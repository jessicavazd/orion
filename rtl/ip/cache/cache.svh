`ifndef CACHE_SVH
`define CACHE_SVH

`define ADDR_W 32
`define DATA_W 32
`define LINE_BYTES 32
`define CACHE_SIZE 1024
`define ASSOC 4
// `define REPLACEMENT_POLICY 0 // 0: PLRU, 1: Random

typedef struct packed {
  logic                 valid;
  logic [ADDR_W-1:0]    addr;
  logic                 wen;
  logic [DATA_W/8-1:0]  wmask;
  logic [DATA_W-1:0]    wdata;
} cache_req_t;

// typedef struct packed {
//   logic                           valid;
//   logic [ADDR_W-1:0]              addr;
//   logic                           wen;
//   logic [LINE_BYTES*8/DATA_W-1:0] wmask;
//   logic [LINE_BYTES*8-1:0]        wdata;
// } mem_req_t;


`endif 


// STAGE 1: REQUEST CAPTURE | INITIATE REQ TO SRAM
// Extract cpu request
// Extract index
// Use index to read tags, valid, dirty, data, plru bits

// STAGE 2: TAG LOOKUP, DATA ACCESS | RECIEVE RESP FROM SRAM & DECIDE HIT/MISS
// Compare stored tags against tag of same req determine hit/miss --> S2 TAG
// Select the correct data word based on offset --> S2 OFFSET
// On hit: read/modify/write data array, send resp to cpu
// On miss: decide victim way, if dirty writeback, send req to mem, wait for resp, update cache, send resp to cpu


// Cycle N:
//   s1_req.addr = A
//   s1_index = index(A)
//   → SRAM read begins

// Cycle N+1:
//   s2_req.addr = A   (registered)
//   s2_tag = tag(A)
//   s2_offset = offset(A)
//   SRAM outputs valid for index(A)
//   → tag compare, word select, resp

  localparam int WORD_BYTES   = DATA_W/8; // 4 BYTES GIVEN 32 BITS
  localparam int WORDS_PER_LINE = LINE_BYTES / WORD_BYTES;
  localparam int WORD_SEL_W   = (WORDS_PER_LINE <= 1) ? 0 : $clog2(WORDS_PER_LINE);