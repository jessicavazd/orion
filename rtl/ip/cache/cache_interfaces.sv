
interface cache_cpu_if #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
);

    logic                   valid; // from cpu 
    logic [ADDR_W-1:0]      addr;
    logic                   wen;
    logic [DATA_W/8-1:0]    wmask;
    logic [DATA_W-1:0]      wdata;
    logic [DATA_W-1:0]      rdata;
    logic                   resp; // from cache

    modport cpu (
        input resp, rdata,
        output valid, addr, wen, wmask, wdata
    );

    modport cache (
        input valid, addr, wen, wmask, wdata,
        output resp, rdata
    );
endinterface

interface cache_mem_if #(
  parameter int ADDR_W = 32,
  parameter int LINE_W = 256
);

    logic                       mem_valid; // from cache
    logic [ADDR_W-1:0]          mem_addr; // should be aligned to LINE_W
    logic                       mem_wr; // 1: write, 0: read
    logic [LINE_W-1:0]          mem_wline;
    logic [LINE_W-1:0]          mem_rline;
    logic                       mem_resp; // from memory


    modport cache (
        input mem_resp, mem_rline,
        output mem_valid, mem_addr, mem_wr, mem_wline
    );

    modport mem (
        input mem_valid, mem_addr, mem_wr, mem_wline,
        output mem_resp, mem_rline
    );
endinterface