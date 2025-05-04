`ifndef __UTILS_SVH__
`define __UTILS_SVH__

`define UNUSED_VAR(var) always_ff @(posedge |var) begin end
`define UNDRIVEN_VAR(var) assign var = 'x; 

`endif // __UTILS_SVH__
