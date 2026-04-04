`ifndef __UTILS_SVH__
`define __UTILS_SVH__

`define UNUSED_VAR(var)     always_ff @(var) begin end

`define UNUSED_PARAM(x)  /* verilator lint_off UNUSED */ \
                         localparam  __``x = x; \
                         /* verilator lint_on UNUSED */

`define UNDRIVEN_VAR(var)   assign var = 'x; 


`define ABS(x)              (($signed(x) < 0) ? (-$signed(x)) : (x));
`define MIN(x, y)           (((x) < (y)) ? (x) : (y))
`define MAX(x, y)           (((x) > (y)) ? (x) : (y))

// Debug macro: expands to the contained statement in simulation, no-op otherwise
`ifdef SIMULATION
    `define DBG(stmt) stmt
`else
    `define DBG(stmt)
`endif

`endif // __UTILS_SVH__
