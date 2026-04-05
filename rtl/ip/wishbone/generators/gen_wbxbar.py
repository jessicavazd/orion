################################################################################
# Wishbone crossbar generator
################################################################################
#                +--------------------------------------+
# Master0 ------>|(wbm0_*)                      (wbs0_*)| <-- Slave0
# Master1 ------>|(wbm1_*)     M x N crossbar   (wbs1_*)| <-- Slave1
# ...            |                                      | ...
# Master<M-1> -->|(wbm<m-1>_*)              (wbs<n-1>_*)| <-- Slave<N-1>
#                +--------------------------------------+
################################################################################
import argparse
import math
from jinja2 import Template
import sys


def clog2_ceil(n):
    return max(1, math.ceil(math.log2(max(n, 2))))


def gen_priority_encoder(name="Priority_encoder"):
    t = f"""
module {name} #(
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
        onehot_o = {{WIDTH{{1'b0}}}};
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
endmodule // {name}
"""
    return t


def gen_wb_demux(n_slaves, name=None):
    assert n_slaves > 0, "Number of slaves must be greater than 0"
    if name is None:
        name = f"Demux{n_slaves}_wb"
    t = Template("""// Wishbone demux {{name}}: 1 master -> {{n_slaves|length}} slaves
module {{name}} #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    {%- for p in n_slaves %}
    parameter DEVICE{{p}}_ADDR = 32'h00000000,
    parameter DEVICE{{p}}_MASK = 32'h0000ff00,
    {%- endfor %}

    // derived parameters
    parameter SELECT_WIDTH = (DATA_WIDTH/8)
) (
    // Wishbone master input
    input  wire [ADDR_WIDTH-1:0]   wbm_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm_dat_o,
    input  wire                    wbm_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm_sel_i,
    input  wire                    wbm_stb_i,
    input  wire                    wbm_cyc_i,
    output wire                    wbm_ack_o,
    output wire                    wbm_err_o,
    {% for p in n_slaves %}
    // Wishbone slave {{p}} port
    output wire [ADDR_WIDTH-1:0]   wbs{{p}}_adr_o,
    input  wire [DATA_WIDTH-1:0]   wbs{{p}}_dat_i,
    output wire [DATA_WIDTH-1:0]   wbs{{p}}_dat_o,
    output wire                    wbs{{p}}_we_o,
    output wire [SELECT_WIDTH-1:0] wbs{{p}}_sel_o,
    output wire                    wbs{{p}}_cyc_o,
    output wire                    wbs{{p}}_stb_o,
    input  wire                    wbs{{p}}_ack_i,
    input  wire                    wbs{{p}}_err_i{%- if p != n_slaves|length - 1 %},{% endif %}
    {% endfor %}
);
    // slave selection logic
    reg [{{clog2_n_slaves-1}}:0] selected_slave;
    reg slave_valid;
    always @(*) begin
        selected_slave = {{clog2_n_slaves}}'b0;
        slave_valid = 1'b0;
        if (wbm_cyc_i) begin
            {%- for p in n_slaves %}
            {% if p == 0 %}if{% else %}else if{% endif %} ((wbm_adr_i & DEVICE{{p}}_MASK) == (DEVICE{{p}}_ADDR & DEVICE{{p}}_MASK)) begin
                selected_slave = {{clog2_n_slaves}}'d{{p}};
                slave_valid = 1'b1;
            end
            {%- endfor %}
        end
    end
                 
    // Master Addr Out
    {%- for p in n_slaves %}
    assign wbs{{p}}_adr_o = wbm_adr_i;
    {%- endfor %}
                 
    // Master Data in (Muxed)
    reg [DATA_WIDTH-1:0] dat_muxed;
    always @(*) begin /* COMBINATORIAL */
        case(selected_slave)
            {%- for p in n_slaves %}
            {{clog2_n_slaves}}'d{{p}}:    dat_muxed = wbs{{p}}_dat_i;
            {%- endfor %}
            default: dat_muxed = {DATA_WIDTH{1'b0}};
        endcase
    end
    assign wbm_dat_o = slave_valid ? dat_muxed : {DATA_WIDTH{1'b0}};
                 
    // Master data out
    {%- for p in n_slaves %}
    assign wbs{{p}}_dat_o = wbm_dat_i;
    {%- endfor %}
                 
    // Master we signals
    {%- for p in n_slaves %}
    assign wbs{{p}}_we_o = wbm_we_i;
    {%- endfor %}
    
    // Master select signals
    {%- for p in n_slaves %}
    assign wbs{{p}}_sel_o = wbm_sel_i;
    {%- endfor %}

    // One-hot slave select — decode once and reuse for both cyc and stb
    {%- for p in n_slaves %}
    wire slave{{p}}_sel = slave_valid && (selected_slave == {{clog2_n_slaves}}'d{{p}});
    {%- endfor %}

    // Cyc muxing
    {%- for p in n_slaves %}
    assign wbs{{p}}_cyc_o = wbm_cyc_i && slave{{p}}_sel;
    {%- endfor %}

    // Master strobe signals
    {%- for p in n_slaves %}
    assign wbs{{p}}_stb_o = wbm_stb_i && slave{{p}}_sel;
    {%- endfor %}

    // Ack signals
    assign wbm_ack_o = (
    {%- for p in n_slaves %}
        (wbs{{p}}_ack_i && slave{{p}}_sel){% if p != n_slaves|length - 1 %} ||{% endif %}
    {%- endfor %});

    // Error signals
    wire err_none_selected = wbm_cyc_i && wbm_stb_i && !slave_valid;
    wire err_from_slave = (
    {%- for p in n_slaves %}
        (wbs{{p}}_err_i && slave{{p}}_sel){% if p != n_slaves|length - 1 %} ||{% endif %}
    {%- endfor %});
    assign wbm_err_o = err_none_selected || err_from_slave;
endmodule
""")
    return t.render(n_slaves=range(n_slaves), clog2_n_slaves=clog2_ceil(n_slaves), name=name)


def gen_arbiter(n_ports, name=None, pe_name="Priority_encoder", policy='priority', priority_lsb_high=0):
    assert n_ports > 0, "Number of ports must be greater than 0"
    if name is None:
        name = f"Arbiter{n_ports}"

    t = Template("""// Arbiter {{name}}: {{n_ports|length}} request ports
module {{name}} #(
    parameter ARB_TYPE_ROUND_ROBIN  = {{arb_type_round_robin}},  // 0=fixed-priority, 1=round-robin
    parameter ARB_LSB_HIGH_PRIORITY = {{priority_lsb_high}}       // 1=port0 highest in fixed-priority mode
)(
    input  wire             clk_i,
    input  wire             rst_i,
    input  wire [{{n_ports|length-1}}:0] request_i,
    output wire [{{n_ports|length-1}}:0] grant_o,
    output wire             grant_valid_o
);
    // In round-robin mode use LSB=1 so arbitration cycles 0,1,...,N-1,0,...
    // In fixed-priority mode ARB_LSB_HIGH_PRIORITY selects which end wins.
    localparam PE_LSB_PRIO = ARB_TYPE_ROUND_ROBIN ? 1 : ARB_LSB_HIGH_PRIORITY;

    reg [{{n_ports|length-1}}:0] grant_reg       = {{n_ports|length}}'b0;
    reg                          grant_valid_reg  = 1'b0;
    reg [{{n_ports|length-1}}:0] mask_reg         = {{n_ports|length}}'b0;
    reg [{{n_ports|length-1}}:0] grant_next, mask_next;
    reg                          grant_valid_next;

    assign grant_o       = grant_reg;
    assign grant_valid_o = grant_valid_reg;

    wire [{{clog2_n_ports-1}}:0] req_idx;
    wire [{{n_ports|length-1}}:0] req_mask;
    wire req_valid;

    {{pe_name}} #(
        .WIDTH({{n_ports|length}}),
        .LSB_HIGH_PRIORITY(PE_LSB_PRIO)
    ) pe_unmasked (
        .inp_i(request_i),
        .enc_o(req_idx),
        .onehot_o(req_mask),
        .valid_o(req_valid)
    );

    // Masked PE for round-robin: request & mask_reg exposes only ports after last grant
    wire [{{clog2_n_ports-1}}:0] masked_req_idx;
    wire [{{n_ports|length-1}}:0] masked_req_mask;
    wire masked_req_valid;

    {{pe_name}} #(
        .WIDTH({{n_ports|length}}),
        .LSB_HIGH_PRIORITY(PE_LSB_PRIO)
    ) pe_masked (
        .inp_i(request_i & mask_reg),
        .enc_o(masked_req_idx),
        .onehot_o(masked_req_mask),
        .valid_o(masked_req_valid)
    );

    always @(*) begin
        grant_next       = {{n_ports|length}}'b0;
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
                    mask_next = ~(( {{n_ports|length}}'b1 << (masked_req_idx + 1)) - {{n_ports|length}}'b1);
                end else begin
                    // Mask exhausted: wrap around, grant unmasked winner
                    grant_next       = req_mask;
                    grant_valid_next = 1'b1;
                    mask_next = ~(( {{n_ports|length}}'b1 << (req_idx + 1)) - {{n_ports|length}}'b1);
                end
            end else begin
                grant_next       = req_mask;
                grant_valid_next = 1'b1;
            end
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            grant_reg       <= {{n_ports|length}}'b0;
            grant_valid_reg <= 1'b0;
            mask_reg        <= {{n_ports|length}}'b0;
        end else begin
            grant_reg       <= grant_next;
            grant_valid_reg <= grant_valid_next;
            mask_reg        <= mask_next;
        end
    end

endmodule // {{name}}
""")

    return t.render(
        n_ports=range(n_ports),
        clog2_n_ports=clog2_ceil(n_ports),
        name=name,
        pe_name=pe_name,
        arb_type_round_robin=1 if policy == 'rr' else 0,
        priority_lsb_high=1 if priority_lsb_high else 0
    )


def gen_wb_mux(n_masters, name=None, arbiter_name=None, pe_name="Priority_encoder", policy='priority', priority_lsb_high=0):
    assert n_masters > 0, "Number of masters must be greater than 0"
    if name is None:
        name = f"Arbiter{n_masters}_wb"
    if arbiter_name is None:
        arbiter_name = f"Arbiter{n_masters}"

    t = Template("""// Wishbone mux {{name}}: {{n_masters|length}} masters -> 1 slave
module {{name}} #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter SELECT_WIDTH = (DATA_WIDTH/8),
    parameter ARB_TYPE_ROUND_ROBIN = {{arb_type_round_robin}},
    parameter ARB_M0_HIGH_PRIORITY = {{priority_lsb_high}}
)(
    input  wire             clk_i,
    input  wire             rst_i,

    {% for m in n_masters %}
    // Master {{m}}
    input  wire [ADDR_WIDTH-1:0]   wbm{{m}}_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm{{m}}_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm{{m}}_dat_o,
    input  wire                    wbm{{m}}_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm{{m}}_sel_i,
    input  wire                    wbm{{m}}_stb_i,
    input  wire                    wbm{{m}}_cyc_i,
    output wire                    wbm{{m}}_ack_o,
    output wire                    wbm{{m}}_err_o,
    {% endfor %}

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
    wire [{{n_masters|length-1}}:0] request;
    wire [{{n_masters|length-1}}:0] grant;
    wire arb_grant_valid;

    {% for m in n_masters %}
    assign request[{{m}}] = wbm{{m}}_cyc_i;
    wire wbm{{m}}_grant = grant[{{m}}] && arb_grant_valid;
    {% endfor %}

    {{arbiter_name}} #(
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
    {%- for m in n_masters %}
        wbm{{m}}_grant ? wbm{{m}}_adr_i :
    {%- endfor %}
        '0;

    assign wbs_dat_o =
    {%- for m in n_masters %}
        wbm{{m}}_grant ? wbm{{m}}_dat_i :
    {%- endfor %}
        '0;

    assign wbs_we_o =
    {%- for m in n_masters %}
        wbm{{m}}_grant ? wbm{{m}}_we_i :
    {%- endfor %}
        1'b0;

    assign wbs_sel_o =
    {%- for m in n_masters %}
        wbm{{m}}_grant ? wbm{{m}}_sel_i :
    {%- endfor %}
        '0;

    assign wbs_stb_o =
    {%- for m in n_masters %}
        wbm{{m}}_grant ? wbm{{m}}_stb_i :
    {%- endfor %}
        1'b0;

    assign wbs_cyc_o = arb_grant_valid;

    {% for m in n_masters %}
    assign wbm{{m}}_dat_o = wbs_dat_i;
    assign wbm{{m}}_ack_o = wbs_ack_i && wbm{{m}}_grant;
    assign wbm{{m}}_err_o = wbs_err_i && wbm{{m}}_grant;
    {% endfor %}

endmodule
""")

    return t.render(
        n_masters=range(n_masters),
        name=name,
        arbiter_name=arbiter_name,
        arb_type_round_robin=1 if policy == 'rr' else 0,
        priority_lsb_high=1 if priority_lsb_high else 0
    )


def parse_connectivity(conn_str, n_masters, n_slaves):
    """Parse connectivity string -> {master_idx: sorted_list_of_slave_idx}."""
    if conn_str.strip() == '*:*':
        return {m: list(range(n_slaves)) for m in range(n_masters)}

    result = {m: [] for m in range(n_masters)}
    for rule in conn_str.split(';'):
        rule = rule.strip()
        if not rule:
            continue
        if ':' not in rule:
            raise ValueError(f"Bad connectivity rule '{rule}' — expected 'master:slave,...'")
        m_part, s_part = rule.split(':', 1)
        m_part, s_part = m_part.strip(), s_part.strip()
        masters = list(range(n_masters)) if m_part == '*' else [int(m_part)]
        slaves  = list(range(n_slaves))  if s_part == '*' else [int(s) for s in s_part.split(',')]
        for m in masters:
            for s in slaves:
                if s not in result[m]:
                    result[m].append(s)
    for m in result:
        result[m].sort()
    
    # validate 
    for m, slaves in result.items():
        for s in slaves:
            if s < 0 or s >= n_slaves:
                raise ValueError(f"Invalid slave index {s} in connectivity for master {m}")
        if m < 0 or m >= n_masters:
            raise ValueError(f"Invalid master index {m} in connectivity")
    return result


def invert_connectivity(conn, n_slaves):
    result = {s: [] for s in range(n_slaves)}
    for m, slaves in conn.items():
        for s in slaves:
            if m not in result[s]:
                result[s].append(m)
    for s in result:
        result[s].sort()
    return result

def print_connectivity_matrix(conn):
    print("Connectivity Matrix (M masters x N slaves):", file=sys.stderr)
    def print_table(headers, rows):
        col_widths = [max(len(str(x)) for x in col) for col in zip(headers, *rows)]
        header_line = " | ".join(f"{h:^{w}}" for h, w in zip(headers, col_widths))
        print(header_line, file=sys.stderr)
        print("-+-".join('-' * w for w in col_widths), file=sys.stderr)
        for row in rows:
            print(" | ".join(f"{str(x):^{w}}" for x, w in zip(row, col_widths)), file=sys.stderr)
    headers = [""] + [f"S{s}" for s in range(max(s for slaves in conn.values() for s in slaves)+1)]
    rows = []
    for m in sorted(conn.keys()):
        row = [f"M{m}"] + ["X" if s in conn[m] else "." for s in range(len(headers)-1)]
        rows.append(row)
    print_table(headers, rows)  


def _master_response(m, slaves, inv_conn):
    if not slaves:
        return (
            f"assign wbm{m}_ack_o = 1'b0;\n"
            f"assign wbm{m}_dat_o = {{DATA_WIDTH{{1'b0}}}};\n"
            f"assign wbm{m}_err_o = wbm{m}_cyc_i;\n"
        )

    ack_terms = []
    dat_terms = []
    err_terms = []
    sel_terms = []

    for s in slaves:
        ms = inv_conn[s]
        sel_terms.append(f"m{m}_sel_s{s}")
        if len(ms) == 1:
            dat_terms.append(f"    ({{DATA_WIDTH{{m{m}_sel_s{s}}}}} & wbs{s}_dat_i)")
            ack_terms.append(f"    (m{m}_sel_s{s} & wbs{s}_ack_i)")
            err_terms.append(f"    | (m{m}_sel_s{s} & wbs{s}_err_i)")
        else:
            k = ms.index(m)
            dat_terms.append(f"    ({{DATA_WIDTH{{m{m}_sel_s{s}}}}} & s{s}_wbm{k}_dat)")
            ack_terms.append(f"    s{s}_wbm{k}_ack")
            err_terms.append(f"    | s{s}_wbm{k}_err")

    ack = f"assign wbm{m}_ack_o =\n" + " |\n".join(ack_terms) + ";"
    dat = f"assign wbm{m}_dat_o =\n" + " |\n".join(dat_terms) + ";"
    err = (
        f"assign wbm{m}_err_o = wbm{m}_cyc_i & (\n"
        f"    !({' | '.join(sel_terms)})\n"
        f"{chr(10).join(err_terms)}\n"
        f");"
    )
    return f"{ack}\n\n{dat}\n\n{err}\n"


def gen_xbar_full(name, n_masters, n_slaves, conn, policy='priority', priority_lsb_high=0):
    inv_conn = invert_connectivity(conn, n_slaves)
    contested_sizes = sorted({len(inv_conn[s]) for s in range(n_slaves) if len(inv_conn[s]) >= 2})
    pe_name = f"{name}_Priority_encoder"
    parts = [gen_priority_encoder(pe_name)]

    for sz in contested_sizes:
        parts.append("\n\n")
        parts.append(gen_arbiter(sz, f"{name}_Arbiter{sz}", pe_name, policy, priority_lsb_high))
        parts.append("\n\n")
        parts.append(gen_wb_mux(sz, f"{name}_Arbiter{sz}_wb", f"{name}_Arbiter{sz}", pe_name, policy, priority_lsb_high))

    t = Template("""{% for _ in [] %}{% endfor %}// Wishbone crossbar {{name}}: {{n_masters}} master(s) x {{n_slaves}} slave(s)
module {{name}} #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter SELECT_WIDTH = (DATA_WIDTH/8),
    parameter ARB_TYPE_ROUND_ROBIN = {{arb_type_round_robin}},
    parameter ARB_M0_HIGH_PRIORITY = {{priority_lsb_high}},
    {%- for s in range(n_slaves) %}
    parameter SLAVE{{s}}_ADDR = 32'h00000000,
    parameter SLAVE{{s}}_MASK = 32'h00000000{%- if not loop.last %},{% endif %}
    {%- endfor %}
)(
    input  wire                    clk_i,
    input  wire                    rst_i,
    {% for m in range(n_masters) %}
    // Master {{m}}
    input  wire [ADDR_WIDTH-1:0]   wbm{{m}}_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm{{m}}_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm{{m}}_dat_o,
    input  wire                    wbm{{m}}_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm{{m}}_sel_i,
    input  wire                    wbm{{m}}_stb_i,
    input  wire                    wbm{{m}}_cyc_i,
    output wire                    wbm{{m}}_ack_o,
    output wire                    wbm{{m}}_err_o,
    {% endfor %}
    {% for s in range(n_slaves) %}
    // Slave {{s}}
    output wire [ADDR_WIDTH-1:0]   wbs{{s}}_adr_o,
    output wire [DATA_WIDTH-1:0]   wbs{{s}}_dat_o,
    input  wire [DATA_WIDTH-1:0]   wbs{{s}}_dat_i,
    output wire                    wbs{{s}}_we_o,
    output wire [SELECT_WIDTH-1:0] wbs{{s}}_sel_o,
    output wire                    wbs{{s}}_stb_o,
    output wire                    wbs{{s}}_cyc_o,
    input  wire                    wbs{{s}}_ack_i,
    input  wire                    wbs{{s}}_err_i{%- if not loop.last %},{% endif %}
    {% endfor %}
);

    // Address decode
    {% for m in range(n_masters) %}
    {% for s in conn[m] %}
    wire m{{m}}_sel_s{{s}} = wbm{{m}}_cyc_i && ((wbm{{m}}_adr_i & SLAVE{{s}}_MASK) == (SLAVE{{s}}_ADDR & SLAVE{{s}}_MASK));
    {% endfor %}
    {% endfor %}

    // Per-slave arbitration and muxing
    {% for s in range(n_slaves) %}
    // Slave {{s}}
    {% set ms = inv_conn[s] %}
    {% if ms|length == 0 %}
    assign wbs{{s}}_adr_o = {ADDR_WIDTH{1'b0}};
    assign wbs{{s}}_dat_o = {DATA_WIDTH{1'b0}};
    assign wbs{{s}}_we_o = 1'b0;
    assign wbs{{s}}_sel_o = {SELECT_WIDTH{1'b0}};
    assign wbs{{s}}_stb_o = 1'b0;
    assign wbs{{s}}_cyc_o = 1'b0;
    {% elif ms|length == 1 %}
    assign wbs{{s}}_adr_o = wbm{{ms[0]}}_adr_i;
    assign wbs{{s}}_dat_o = wbm{{ms[0]}}_dat_i;
    assign wbs{{s}}_we_o = wbm{{ms[0]}}_we_i;
    assign wbs{{s}}_sel_o = wbm{{ms[0]}}_sel_i;
    assign wbs{{s}}_stb_o = wbm{{ms[0]}}_stb_i && m{{ms[0]}}_sel_s{{s}};
    assign wbs{{s}}_cyc_o = m{{ms[0]}}_sel_s{{s}};
    {% else %}
    {% for m in ms %}
    wire [DATA_WIDTH-1:0] s{{s}}_wbm{{loop.index0}}_dat;
    wire s{{s}}_wbm{{loop.index0}}_ack;
    wire s{{s}}_wbm{{loop.index0}}_err;
    {% endfor %}

    {{name}}_Arbiter{{ms|length}}_wb #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SELECT_WIDTH(SELECT_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
        .ARB_M0_HIGH_PRIORITY(ARB_M0_HIGH_PRIORITY)
    ) s{{s}}_mux (
        .clk_i(clk_i),
        .rst_i(rst_i),
        {% for m in ms %}
        .wbm{{loop.index0}}_adr_i(wbm{{m}}_adr_i),
        .wbm{{loop.index0}}_dat_i(wbm{{m}}_dat_i),
        .wbm{{loop.index0}}_dat_o(s{{s}}_wbm{{loop.index0}}_dat),
        .wbm{{loop.index0}}_we_i(wbm{{m}}_we_i),
        .wbm{{loop.index0}}_sel_i(wbm{{m}}_sel_i),
        .wbm{{loop.index0}}_stb_i(wbm{{m}}_stb_i),
        .wbm{{loop.index0}}_cyc_i(m{{m}}_sel_s{{s}}),
        .wbm{{loop.index0}}_ack_o(s{{s}}_wbm{{loop.index0}}_ack),
        .wbm{{loop.index0}}_err_o(s{{s}}_wbm{{loop.index0}}_err),
        {% endfor %}
        .wbs_adr_o(wbs{{s}}_adr_o),
        .wbs_dat_i(wbs{{s}}_dat_i),
        .wbs_dat_o(wbs{{s}}_dat_o),
        .wbs_we_o(wbs{{s}}_we_o),
        .wbs_sel_o(wbs{{s}}_sel_o),
        .wbs_stb_o(wbs{{s}}_stb_o),
        .wbs_cyc_o(wbs{{s}}_cyc_o),
        .wbs_ack_i(wbs{{s}}_ack_i),
        .wbs_err_i(wbs{{s}}_err_i)
    );
    {% endif %}
    {% endfor %}

    // Per-master response routing
    {% for m in range(n_masters) %}
    {{master_resp[m]}}
    {% endfor %}
endmodule
""")

    parts.append("\n\n")
    parts.append(t.render(
        name=name,
        n_masters=n_masters,
        n_slaves=n_slaves,
        conn=conn,
        inv_conn=inv_conn,
        master_resp={m: _master_response(m, conn[m], inv_conn) for m in range(n_masters)},
        arb_type_round_robin=1 if policy == 'rr' else 0,
        priority_lsb_high=1 if priority_lsb_high else 0,
        clog2_sizes={sz: clog2_ceil(sz) for sz in contested_sizes}
    ))
    return "".join(parts)


def gen_xbar_shared(name, n_masters, n_slaves, policy='priority', priority_lsb_high=0):
    arbiter_name = f"{name}_Arbiter{n_masters}"
    mux_name = f"{name}_Arbiter{n_masters}_wb"
    demux_name = f"{name}_Demux{n_slaves}_wb"

    pe_name = f"{name}_Priority_encoder"
    parts = [gen_priority_encoder(pe_name), "\n\n"]
    parts.append(gen_arbiter(n_masters, arbiter_name, pe_name, policy, priority_lsb_high))
    parts.append("\n\n")
    parts.append(gen_wb_mux(n_masters, mux_name, arbiter_name, pe_name, policy, priority_lsb_high))
    parts.append("\n\n")
    parts.append(gen_wb_demux(n_slaves, demux_name))
    parts.append("\n\n")

    t = Template("""// Wishbone shared crossbar {{name}}: {{n_masters}} master(s) -> 1 shared path -> {{n_slaves}} slave(s)
module {{name}} #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter SELECT_WIDTH = (DATA_WIDTH/8),
    parameter ARB_TYPE_ROUND_ROBIN = {{arb_type_round_robin}},
    parameter ARB_M0_HIGH_PRIORITY = {{priority_lsb_high}},
    {%- for s in range(n_slaves) %}
    parameter SLAVE{{s}}_ADDR = 32'h00000000,
    parameter SLAVE{{s}}_MASK = 32'h00000000{%- if not loop.last %},{% endif %}
    {%- endfor %}
)(
    input  wire                    clk_i,
    input  wire                    rst_i,
    {% for m in range(n_masters) %}
    // Master {{m}}
    input  wire [ADDR_WIDTH-1:0]   wbm{{m}}_adr_i,
    input  wire [DATA_WIDTH-1:0]   wbm{{m}}_dat_i,
    output wire [DATA_WIDTH-1:0]   wbm{{m}}_dat_o,
    input  wire                    wbm{{m}}_we_i,
    input  wire [SELECT_WIDTH-1:0] wbm{{m}}_sel_i,
    input  wire                    wbm{{m}}_stb_i,
    input  wire                    wbm{{m}}_cyc_i,
    output wire                    wbm{{m}}_ack_o,
    output wire                    wbm{{m}}_err_o,
    {% endfor %}
    {% for s in range(n_slaves) %}
    // Slave {{s}}
    output wire [ADDR_WIDTH-1:0]   wbs{{s}}_adr_o,
    output wire [DATA_WIDTH-1:0]   wbs{{s}}_dat_o,
    input  wire [DATA_WIDTH-1:0]   wbs{{s}}_dat_i,
    output wire                    wbs{{s}}_we_o,
    output wire [SELECT_WIDTH-1:0] wbs{{s}}_sel_o,
    output wire                    wbs{{s}}_stb_o,
    output wire                    wbs{{s}}_cyc_o,
    input  wire                    wbs{{s}}_ack_i,
    input  wire                    wbs{{s}}_err_i{%- if not loop.last %},{% endif %}
    {% endfor %}
);
    wire [ADDR_WIDTH-1:0]   shared_adr;
    wire [DATA_WIDTH-1:0]   shared_dat_m2s;
    wire [DATA_WIDTH-1:0]   shared_dat_s2m;
    wire                    shared_we;
    wire [SELECT_WIDTH-1:0] shared_sel;
    wire                    shared_stb;
    wire                    shared_cyc;
    wire                    shared_ack;
    wire                    shared_err;

    {{mux_name}} #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SELECT_WIDTH(SELECT_WIDTH),
        .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
        .ARB_M0_HIGH_PRIORITY(ARB_M0_HIGH_PRIORITY)
    ) shared_mux (
        .clk_i(clk_i),
        .rst_i(rst_i),
        {% for m in range(n_masters) %}
        .wbm{{m}}_adr_i(wbm{{m}}_adr_i),
        .wbm{{m}}_dat_i(wbm{{m}}_dat_i),
        .wbm{{m}}_dat_o(wbm{{m}}_dat_o),
        .wbm{{m}}_we_i(wbm{{m}}_we_i),
        .wbm{{m}}_sel_i(wbm{{m}}_sel_i),
        .wbm{{m}}_stb_i(wbm{{m}}_stb_i),
        .wbm{{m}}_cyc_i(wbm{{m}}_cyc_i),
        .wbm{{m}}_ack_o(wbm{{m}}_ack_o),
        .wbm{{m}}_err_o(wbm{{m}}_err_o),
        {% endfor %}
        .wbs_adr_o(shared_adr),
        .wbs_dat_i(shared_dat_s2m),
        .wbs_dat_o(shared_dat_m2s),
        .wbs_we_o(shared_we),
        .wbs_sel_o(shared_sel),
        .wbs_stb_o(shared_stb),
        .wbs_cyc_o(shared_cyc),
        .wbs_ack_i(shared_ack),
        .wbs_err_i(shared_err)
    );

    {{demux_name}} #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SELECT_WIDTH(SELECT_WIDTH),
        {% for s in range(n_slaves) %}
        .DEVICE{{s}}_ADDR(SLAVE{{s}}_ADDR),
        .DEVICE{{s}}_MASK(SLAVE{{s}}_MASK){% if not loop.last %},{% endif %}
        {% endfor %}
    ) shared_demux (
        .wbm_adr_i(shared_adr),
        .wbm_dat_i(shared_dat_m2s),
        .wbm_dat_o(shared_dat_s2m),
        .wbm_we_i(shared_we),
        .wbm_sel_i(shared_sel),
        .wbm_stb_i(shared_stb),
        .wbm_cyc_i(shared_cyc),
        .wbm_ack_o(shared_ack),
        .wbm_err_o(shared_err),
        {% for s in range(n_slaves) %}
        .wbs{{s}}_adr_o(wbs{{s}}_adr_o),
        .wbs{{s}}_dat_i(wbs{{s}}_dat_i),
        .wbs{{s}}_dat_o(wbs{{s}}_dat_o),
        .wbs{{s}}_we_o(wbs{{s}}_we_o),
        .wbs{{s}}_sel_o(wbs{{s}}_sel_o),
        .wbs{{s}}_cyc_o(wbs{{s}}_cyc_o),
        .wbs{{s}}_stb_o(wbs{{s}}_stb_o),
        .wbs{{s}}_ack_i(wbs{{s}}_ack_i),
        .wbs{{s}}_err_i(wbs{{s}}_err_i){% if not loop.last %},{% endif %}
        {% endfor %}
    );
endmodule
""")

    parts.append(t.render(
        name=name,
        n_masters=n_masters,
        n_slaves=n_slaves,
        mux_name=mux_name,
        demux_name=demux_name,
        arb_type_round_robin=1 if policy == 'rr' else 0,
        priority_lsb_high=1 if priority_lsb_high else 0
    ))
    return "".join(parts)


def gen_tb_xbar(name, n_masters, n_slaves, conn=None, tb_name=None, cycles=300, topology='full'):
    if tb_name is None:
        tb_name = f"{name}_tb"
    if conn is None:
        conn = {m: list(range(n_slaves)) for m in range(n_masters)}
    param_lines = []
    for s in range(n_slaves):
        base = (s & 0xF) << 28
        param_lines.append(f"localparam logic [31:0] S{s}_ADDR = 32'h{base:08X};")
        param_lines.append(f"localparam logic [31:0] S{s}_MASK = 32'hF0000000;")
    choose_cases = []
    for m in range(n_masters):
        allowed = conn.get(m, [])
        if allowed:
            choices = ", ".join([str(s) for s in allowed])
            choose_cases.append(f"""            {m}: begin
                int opts [0:{len(allowed)-1}] = '{{{choices}}};
                choose_slave_for_master = opts[$urandom_range(0, {len(allowed)-1})];
            end""")
        else:
            choose_cases.append(f"            {m}: choose_slave_for_master = -1;")

    allowed0 = conn.get(0, [])
    d2_slave = allowed0[0] if allowed0 else None
    d3_slave = allowed0[1] if len(allowed0) > 1 else None

    d4_enabled = False
    d4_m0_slave = None
    d4_m1_slave = None
    if n_masters > 1:
        allowed1 = conn.get(1, [])
        if topology == 'shared':
            if allowed0 and allowed1:
                d4_m0_slave = allowed0[0]
                d4_m1_slave = next((s for s in allowed1 if s != d4_m0_slave), allowed1[0])
                d4_enabled = True
        else:
            for s0 in allowed0:
                for s1 in allowed1:
                    if s0 != s1:
                        d4_m0_slave = s0
                        d4_m1_slave = s1
                        d4_enabled = True
                        break
                if d4_enabled:
                    break

    t = Template("""`timescale 1ns/1ps
`default_nettype none

module {{tb_name}};
localparam int DATA_WIDTH = 32;
localparam int ADDR_WIDTH = 32;
localparam int SELECT_WIDTH = (DATA_WIDTH/8);
localparam int TEST_CYCLES = {{cycles}};
localparam int MASTER_ISSUE_PCT = 40;
localparam int MASTER_INVALID_PCT = 10;
localparam int SLAVE_ERR_PCT = 8;
localparam int SLAVE_MAX_LATENCY = 4;
localparam int M_IDLE = 0;
localparam int M_WAIT = 1;
localparam int S_IDLE = 0;
localparam int S_WAIT = 1;
localparam int S_RESP = 2;
localparam int S_DRAIN = 3;
{{param_text}}

logic clk = 1'b0;
logic rst = 1'b1;
always #5 clk = ~clk;

logic [ADDR_WIDTH-1:0]   wbm_adr_i [0:{{n_masters-1}}];
logic [DATA_WIDTH-1:0]   wbm_dat_i [0:{{n_masters-1}}];
logic [DATA_WIDTH-1:0]   wbm_dat_o [0:{{n_masters-1}}];
logic                    wbm_we_i  [0:{{n_masters-1}}];
logic [SELECT_WIDTH-1:0] wbm_sel_i [0:{{n_masters-1}}];
logic                    wbm_stb_i [0:{{n_masters-1}}];
logic                    wbm_cyc_i [0:{{n_masters-1}}];
logic                    wbm_ack_o [0:{{n_masters-1}}];
logic                    wbm_err_o [0:{{n_masters-1}}];

logic [ADDR_WIDTH-1:0]   wbs_adr_o [0:{{n_slaves-1}}];
logic [DATA_WIDTH-1:0]   wbs_dat_o [0:{{n_slaves-1}}];
logic [DATA_WIDTH-1:0]   wbs_dat_i [0:{{n_slaves-1}}];
logic                    wbs_we_o  [0:{{n_slaves-1}}];
logic [SELECT_WIDTH-1:0] wbs_sel_o [0:{{n_slaves-1}}];
logic                    wbs_stb_o [0:{{n_slaves-1}}];
logic                    wbs_cyc_o [0:{{n_slaves-1}}];
logic                    wbs_ack_i [0:{{n_slaves-1}}];
logic                    wbs_err_i [0:{{n_slaves-1}}];

int cycle_count;
int pass_cnt = 0;
int fail_cnt = 0;

int master_state      [0:{{n_masters-1}}];
int master_target     [0:{{n_masters-1}}];
int master_start      [0:{{n_masters-1}}];
logic [ADDR_WIDTH-1:0] master_addr_latched [0:{{n_masters-1}}];
logic                  master_read_latched [0:{{n_masters-1}}];
logic [DATA_WIDTH-1:0] master_expected_dat [0:{{n_masters-1}}];
int master_issued     [0:{{n_masters-1}}];
int master_completed  [0:{{n_masters-1}}];
int master_errors     [0:{{n_masters-1}}];
int master_wait_cycles[0:{{n_masters-1}}];
int master_latency_sum[0:{{n_masters-1}}];

int slave_state       [0:{{n_slaves-1}}];
int slave_countdown   [0:{{n_slaves-1}}];
bit slave_resp_err    [0:{{n_slaves-1}}];
logic [ADDR_WIDTH-1:0] slave_req_addr [0:{{n_slaves-1}}];
logic [DATA_WIDTH-1:0] slave_resp_dat [0:{{n_slaves-1}}];
int slave_busy_cycles [0:{{n_slaves-1}}];
int slave_acks        [0:{{n_slaves-1}}];
int slave_errs        [0:{{n_slaves-1}}];

int total_issued;
int total_completed;
int total_errors;
int contention_cycles;
int max_active_masters;

task automatic check(input bit cond, input string msg);
    begin
        if (cond) pass_cnt = pass_cnt + 1;
        else begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL: %0s at t=%0t", msg, $time);
        end
    end
endtask

task automatic master_idle(input int m);
    begin
        wbm_adr_i[m] = '0;
        wbm_dat_i[m] = '0;
        wbm_we_i[m]  = 1'b0;
        wbm_sel_i[m] = '0;
        wbm_stb_i[m] = 1'b0;
        wbm_cyc_i[m] = 1'b0;
    end
endtask

task automatic master_drive_req(input int m, input int s, input bit invalid_addr);
    logic [ADDR_WIDTH-1:0] addr;
    begin
        if (invalid_addr || s < 0) begin
            addr = 32'hF0000000 ^ (m << 8) ^ cycle_count;
            master_target[m] = -1;
        end else begin
            case (s)
{% for s in range(n_slaves) %}
                {{s}}: addr = S{{s}}_ADDR | ($urandom() & ~S{{s}}_MASK);
{% endfor %}
                default: addr = 32'hE0000000 ^ (m << 8);
            endcase
            master_target[m] = s;
        end
        wbm_adr_i[m] = addr;
        wbm_dat_i[m] = $urandom();
        wbm_we_i[m]  = $urandom_range(0, 1);
        wbm_sel_i[m] = {SELECT_WIDTH{1'b1}};
        wbm_stb_i[m] = 1'b1;
        wbm_cyc_i[m] = 1'b1;
        master_start[m] = cycle_count;
        master_addr_latched[m] = addr;
        master_read_latched[m] = !wbm_we_i[m];
        if (s >= 0)
            master_expected_dat[m] = addr ^ (32'h1357_0000 + s);
        else
            master_expected_dat[m] = '0;
        master_issued[m] = master_issued[m] + 1;
        total_issued = total_issued + 1;
        master_state[m] = M_WAIT;
    end
endtask

task automatic slave_idle(input int s);
    begin
        wbs_dat_i[s] = '0;
        wbs_ack_i[s] = 1'b0;
        wbs_err_i[s] = 1'b0;
    end
endtask

task automatic slave_respond(input int s, input bit err, input logic [DATA_WIDTH-1:0] dat);
    begin
        wbs_dat_i[s] = dat;
        wbs_ack_i[s] = !err;
        wbs_err_i[s] = err;
    end
endtask

function automatic int choose_slave_for_master(input int m);
    begin
        choose_slave_for_master = -1;
        case (m)
{{choose_cases}}
            default: choose_slave_for_master = -1;
        endcase
    end
endfunction

{{name}} #(
{% for s in range(n_slaves) %}
    .SLAVE{{s}}_ADDR(S{{s}}_ADDR),
    .SLAVE{{s}}_MASK(S{{s}}_MASK){% if not loop.last %},{% endif %}
{% endfor %}
) dut (
    .clk(clk),
    .rst(rst),
{% for m in range(n_masters) %}
    .wbm{{m}}_adr_i(wbm_adr_i[{{m}}]),
    .wbm{{m}}_dat_i(wbm_dat_i[{{m}}]),
    .wbm{{m}}_dat_o(wbm_dat_o[{{m}}]),
    .wbm{{m}}_we_i(wbm_we_i[{{m}}]),
    .wbm{{m}}_sel_i(wbm_sel_i[{{m}}]),
    .wbm{{m}}_stb_i(wbm_stb_i[{{m}}]),
    .wbm{{m}}_cyc_i(wbm_cyc_i[{{m}}]),
    .wbm{{m}}_ack_o(wbm_ack_o[{{m}}]),
    .wbm{{m}}_err_o(wbm_err_o[{{m}}]),
{% endfor %}
{% for s in range(n_slaves) %}
    .wbs{{s}}_adr_o(wbs_adr_o[{{s}}]),
    .wbs{{s}}_dat_o(wbs_dat_o[{{s}}]),
    .wbs{{s}}_dat_i(wbs_dat_i[{{s}}]),
    .wbs{{s}}_we_o(wbs_we_o[{{s}}]),
    .wbs{{s}}_sel_o(wbs_sel_o[{{s}}]),
    .wbs{{s}}_stb_o(wbs_stb_o[{{s}}]),
    .wbs{{s}}_cyc_o(wbs_cyc_o[{{s}}]),
    .wbs{{s}}_ack_i(wbs_ack_i[{{s}}]),
    .wbs{{s}}_err_i(wbs_err_i[{{s}}]){% if not loop.last %},{% endif %}
{% endfor %}
);

integer i;
integer active_masters;
integer active_on_slave;
integer chosen_slave;
integer resp_latency;
logic directed_phase = 1'b1; // suppresses state machines during directed tests

always @(posedge clk) begin
    if (rst) begin
        cycle_count <= 0;
        total_issued <= 0;
        total_completed <= 0;
        total_errors <= 0;
        contention_cycles <= 0;
        max_active_masters <= 0;
        for (i = 0; i < {{n_masters}}; i = i + 1) begin
            master_idle(i);
            master_state[i] <= M_IDLE;
            master_target[i] <= -1;
            master_start[i] <= 0;
            master_addr_latched[i] <= '0;
            master_read_latched[i] <= 1'b0;
            master_expected_dat[i] <= '0;
            master_issued[i] <= 0;
            master_completed[i] <= 0;
            master_errors[i] <= 0;
            master_wait_cycles[i] <= 0;
            master_latency_sum[i] <= 0;
        end
        for (i = 0; i < {{n_slaves}}; i = i + 1) begin
            slave_idle(i);
            slave_state[i] <= S_IDLE;
            slave_countdown[i] <= 0;
            slave_resp_err[i] <= 1'b0;
            slave_req_addr[i] <= '0;
            slave_resp_dat[i] <= '0;
            slave_busy_cycles[i] <= 0;
            slave_acks[i] <= 0;
            slave_errs[i] <= 0;
        end
    end else begin
        // ── Protocol checks — run BEFORE state machines modify any signals ──
{% for m in range(n_masters) %}
        check(!(wbm_ack_o[{{m}}] && wbm_err_o[{{m}}]),
              $sformatf("M{{m}} ack/err mutually exclusive"));
        check(!(wbm_ack_o[{{m}}] && !wbm_cyc_i[{{m}}]),
              $sformatf("M{{m}} ack_o without cyc_i"));
        check(!(wbm_err_o[{{m}}] && !wbm_cyc_i[{{m}}]),
              $sformatf("M{{m}} err_o without cyc_i"));
{% endfor %}
{% for s in range(n_slaves) %}
        check(!(wbs_stb_o[{{s}}] && !wbs_cyc_o[{{s}}]),
              $sformatf("S{{s}} stb_o without cyc_o"));
{% endfor %}
        if (!directed_phase) begin
        cycle_count <= cycle_count + 1;

        active_masters = 0;
        for (i = 0; i < {{n_masters}}; i = i + 1)
            if (master_state[i] == M_WAIT)
                active_masters = active_masters + 1;
        if (active_masters > max_active_masters)
            max_active_masters <= active_masters;

{% if topology == 'shared' %}
        if (active_masters > 1)
            contention_cycles <= contention_cycles + 1;
{% else %}
        for (i = 0; i < {{n_slaves}}; i = i + 1) begin
            active_on_slave = 0;
            for (int m = 0; m < {{n_masters}}; m = m + 1)
                if (master_state[m] == M_WAIT && master_target[m] == i)
                    active_on_slave = active_on_slave + 1;
            if (active_on_slave > 1)
                contention_cycles <= contention_cycles + 1;
        end
{% endif %}

        for (i = 0; i < {{n_slaves}}; i = i + 1) begin
            slave_idle(i);
            case (slave_state[i])
                S_IDLE: begin
                    if (wbs_cyc_o[i] && wbs_stb_o[i]) begin
                        slave_req_addr[i] <= wbs_adr_o[i];
                        slave_resp_err[i] <= ($urandom_range(0, 99) < SLAVE_ERR_PCT);
                        resp_latency = $urandom_range(0, SLAVE_MAX_LATENCY);
                        slave_countdown[i] <= resp_latency;
                        if (resp_latency == 0)
                            slave_state[i] <= S_RESP;
                        else
                            slave_state[i] <= S_WAIT;
                    end
                end
                S_WAIT: begin
                    slave_busy_cycles[i] <= slave_busy_cycles[i] + 1;
                    if (slave_countdown[i] == 0)
                        slave_state[i] <= S_RESP;
                    else
                        slave_countdown[i] <= slave_countdown[i] - 1;
                end
                S_RESP: begin
                    // Respond from the latched request address captured in S_IDLE.
                    // Live bus signals may already be changing on the completion cycle.
                    slave_resp_dat[i] = slave_req_addr[i] ^ (32'h1357_0000 + i);
                    slave_busy_cycles[i] <= slave_busy_cycles[i] + 1;
                    slave_respond(i, slave_resp_err[i], slave_resp_dat[i]);
                    if (slave_resp_err[i])
                        slave_errs[i] <= slave_errs[i] + 1;
                    else
                        slave_acks[i] <= slave_acks[i] + 1;
                    slave_state[i] <= S_DRAIN;
                end
                S_DRAIN: begin
                    if (wbs_cyc_o[i] && wbs_stb_o[i])
                        slave_busy_cycles[i] <= slave_busy_cycles[i] + 1;
                    if (!(wbs_cyc_o[i] && wbs_stb_o[i]))
                        slave_state[i] <= S_IDLE;
                end
            endcase
        end

        for (i = 0; i < {{n_masters}}; i = i + 1) begin
            case (master_state[i])
                M_IDLE: begin
                    master_idle(i);
                    if ($urandom_range(0, 99) < MASTER_ISSUE_PCT) begin
                        chosen_slave = choose_slave_for_master(i);
                        master_drive_req(i, chosen_slave, ($urandom_range(0, 99) < MASTER_INVALID_PCT));
                    end
                end
                M_WAIT: begin
                    master_wait_cycles[i] <= master_wait_cycles[i] + 1;
                    if (wbm_ack_o[i] || wbm_err_o[i]) begin
                        master_completed[i] <= master_completed[i] + 1;
                        total_completed <= total_completed + 1;
                        master_latency_sum[i] <= master_latency_sum[i] + (cycle_count - master_start[i] + 1);
                        if (wbm_err_o[i]) begin
                            master_errors[i] <= master_errors[i] + 1;
                            total_errors <= total_errors + 1;
                        end
                        // Data integrity: on read ack verify returned data
                        if (wbm_ack_o[i] && master_read_latched[i] && master_target[i] >= 0) begin
                            check(wbm_dat_o[i] === master_expected_dat[i],
                                  $sformatf("M%0d read data integrity (tgt=%0d)", i, master_target[i]));
                        end
                        master_state[i] <= M_IDLE;
                        master_target[i] <= -1;
                        master_idle(i);
                    end
                end
            endcase
        end

        end // !directed_phase
    end
end

// ── Directed corner-case tests ────────────────────────────────────────────────
// Run before the randomized stimulus loop.  Uses one-shot initial block so it
// completes before the always block's rst-deassert stimulus takes over.

logic [ADDR_WIDTH-1:0] d_addr;
logic [DATA_WIDTH-1:0] d_rdat;
logic d_ack;
integer d_wait;

task automatic directed_trans(
    input int m, input int s, input bit we,
    input logic [DATA_WIDTH-1:0] wdat,
    output logic [DATA_WIDTH-1:0] rdat, output logic ack
);
    logic [ADDR_WIDTH-1:0] addr;
    begin
        case (s)
{% for s in range(n_slaves) %}
            {{s}}: addr = S{{s}}_ADDR | 32'h4;
{% endfor %}
            default: addr = 32'hDEAD_0000;
        endcase
        // Drive master m
        wbm_adr_i[m] = addr; wbm_dat_i[m] = wdat;
        wbm_we_i[m]  = we;   wbm_sel_i[m] = {SELECT_WIDTH{1'b1}};
        wbm_stb_i[m] = 1'b1; wbm_cyc_i[m] = 1'b1;
        // Slave s responds immediately (0 latency)
        d_wait = 0;
        @(posedge clk); #1;
        wbs_ack_i[s] = wbs_stb_o[s] & wbs_cyc_o[s];
        wbs_dat_i[s] = addr ^ (32'h1357_0000 + s);
        #1; // let combinatorial ack/dat propagate
        ack  = wbm_ack_o[m];
        rdat = wbm_dat_o[m];
        // Deassert
        @(posedge clk); #1;
        wbm_stb_i[m] = 0; wbm_cyc_i[m] = 0;
        wbs_ack_i[s] = 0; wbs_dat_i[s] = 0;
        repeat(2) @(posedge clk);
    end
endtask

initial begin
    // Wait for reset deassert (same timing as always block)
    repeat (4) @(posedge clk);
    @(posedge clk); // one extra cycle after rst deasserts

    $display("\\n--- Directed tests ---");

    // ── D1: Reset — all master outputs must be low ─────────────────────────
    rst = 1'b1;
    @(posedge clk); #1;
{% for m in range(n_masters) %}
    check(wbm_ack_o[{{m}}] === 1'b0, "D1 M{{m}} ack_o low during reset");
    check(wbm_err_o[{{m}}] === 1'b0, "D1 M{{m}} err_o low during reset");
{% endfor %}
{% for s in range(n_slaves) %}
    check(wbs_cyc_o[{{s}}] === 1'b0, "D1 S{{s}} cyc_o low during reset");
    check(wbs_stb_o[{{s}}] === 1'b0, "D1 S{{s}} stb_o low during reset");
{% endfor %}
    rst = 1'b0;
    repeat(2) @(posedge clk);

{% if d2_slave is not none %}
    // ── D2: Single transaction M0->S{{d2_slave}} (read) ─────────────────────────
    directed_trans(0, {{d2_slave}}, 1'b0, 32'h0, d_rdat, d_ack);
    check(d_ack, "D2 M0->S{{d2_slave}} read ack");
    check(d_rdat === ((S{{d2_slave}}_ADDR | 32'h4) ^ (32'h1357_0000 + {{d2_slave}})), "D2 M0->S{{d2_slave}} read data");
{% endif %}

{% if d3_slave is not none %}
    // ── D3: Single transaction M0->S{{d3_slave}} (write) ────────────────────────
    directed_trans(0, {{d3_slave}}, 1'b1, 32'hDEADBEEF, d_rdat, d_ack);
    check(d_ack, "D3 M0->S{{d3_slave}} write ack");
{% endif %}

{% if n_masters > 1 %}
{% if d4_enabled %}
{% if topology == 'shared' %}
    // ── D4: Shared topology serializes simultaneous requests ───────────────
{% else %}
    // ── D4: Two masters, non-conflicting requests can complete together ────
{% endif %}
    @(negedge clk);
    wbm_adr_i[0] = S{{d4_m0_slave}}_ADDR | 32'h8; wbm_cyc_i[0]=1; wbm_stb_i[0]=1; wbm_we_i[0]=0; wbm_sel_i[0]={SELECT_WIDTH{1'b1}};
    wbm_adr_i[1] = S{{d4_m1_slave}}_ADDR | 32'hC; wbm_cyc_i[1]=1; wbm_stb_i[1]=1; wbm_we_i[1]=0; wbm_sel_i[1]={SELECT_WIDTH{1'b1}};
    @(posedge clk); #1;
    wbs_ack_i[{{d4_m0_slave}}]=wbs_stb_o[{{d4_m0_slave}}]&wbs_cyc_o[{{d4_m0_slave}}]; wbs_dat_i[{{d4_m0_slave}}]=(S{{d4_m0_slave}}_ADDR|32'h8)^(32'h1357_0000+{{d4_m0_slave}});
    wbs_ack_i[{{d4_m1_slave}}]=wbs_stb_o[{{d4_m1_slave}}]&wbs_cyc_o[{{d4_m1_slave}}]; wbs_dat_i[{{d4_m1_slave}}]=(S{{d4_m1_slave}}_ADDR|32'hC)^(32'h1357_0000+{{d4_m1_slave}});
    #1;
{% if topology == 'shared' %}
    check(wbm_ack_o[0] ^ wbm_ack_o[1], "D4 shared topology serializes first ack");
{% else %}
    check(wbm_ack_o[0], "D4 M0 concurrent ack");
    check(wbm_ack_o[1], "D4 M1 concurrent ack");
    check(wbm_dat_o[0] === ((S{{d4_m0_slave}}_ADDR|32'h8)^(32'h1357_0000+{{d4_m0_slave}})), "D4 M0 concurrent data");
    check(wbm_dat_o[1] === ((S{{d4_m1_slave}}_ADDR|32'hC)^(32'h1357_0000+{{d4_m1_slave}})), "D4 M1 concurrent data");
{% endif %}
    @(posedge clk); #1;
    wbm_cyc_i[0]=0; wbm_stb_i[0]=0; wbm_cyc_i[1]=0; wbm_stb_i[1]=0;
    wbs_ack_i[{{d4_m0_slave}}]=0; wbs_dat_i[{{d4_m0_slave}}]=0; wbs_ack_i[{{d4_m1_slave}}]=0; wbs_dat_i[{{d4_m1_slave}}]=0;
    repeat(3) @(posedge clk);
{% endif %}

    // ── D5: M0 unmapped address → err_o ──────────────────────────────────
    @(negedge clk);
    wbm_adr_i[0] = 32'hF000_0000; wbm_cyc_i[0]=1; wbm_stb_i[0]=1; wbm_we_i[0]=0; wbm_sel_i[0]={SELECT_WIDTH{1'b1}};
    @(posedge clk); #1;
    check(wbm_err_o[0], "D5 M0 unmapped addr err_o");
    check(!wbm_ack_o[0], "D5 M0 no ack on unmapped");
    wbm_cyc_i[0]=0; wbm_stb_i[0]=0;
    repeat(2) @(posedge clk);

    // ── D6: Multi-cycle stall — grant held while CYC asserted ─────────────
    @(negedge clk);
    wbm_adr_i[0] = S0_ADDR | 32'h10; wbm_cyc_i[0]=1; wbm_stb_i[0]=1; wbm_we_i[0]=0; wbm_sel_i[0]={SELECT_WIDTH{1'b1}};
    wbm_adr_i[1] = S0_ADDR | 32'h14; wbm_cyc_i[1]=1; wbm_stb_i[1]=1; wbm_we_i[1]=0; wbm_sel_i[1]={SELECT_WIDTH{1'b1}};
    // Stall for 4 cycles with no ack
    repeat(4) begin
        @(posedge clk); #1;
        check(wbs_cyc_o[0], "D6 S0 cyc held during stall");
    end
    // Now ack whoever has the grant
    wbs_ack_i[0] = wbs_stb_o[0] & wbs_cyc_o[0];
    wbs_dat_i[0] = 32'hCAFE_0001;
    #1;
    check(wbm_ack_o[0] || wbm_ack_o[1], "D6 one master acked after stall");
    @(posedge clk); #1;
    wbs_ack_i[0]=0; wbm_cyc_i[0]=0; wbm_stb_i[0]=0; wbm_cyc_i[1]=0; wbm_stb_i[1]=0;
    repeat(3) @(posedge clk);

    // ── D7: Slave ERR propagates to correct master only ───────────────────
    @(negedge clk);
    wbm_adr_i[0] = S0_ADDR | 32'h18; wbm_cyc_i[0]=1; wbm_stb_i[0]=1; wbm_we_i[0]=0; wbm_sel_i[0]={SELECT_WIDTH{1'b1}};
    @(posedge clk); #1;
    wbs_err_i[0] = wbs_stb_o[0] & wbs_cyc_o[0];
    #1;
    check(wbm_err_o[0],  "D7 M0 receives slave ERR");
    check(!wbm_ack_o[0], "D7 M0 no ack on slave ERR");
    check(!wbm_err_o[1], "D7 M1 not affected by S0 ERR");
    @(posedge clk); #1;
    wbm_cyc_i[0]=0; wbm_stb_i[0]=0; wbs_err_i[0]=0;
    repeat(3) @(posedge clk);
{% endif %}

    $display("--- Directed tests done, starting randomized ---\\n");
    directed_phase = 1'b0;
end

initial begin
    repeat (4) @(posedge clk);
    rst = 1'b0;
    // Wait for directed tests to hand off
    wait (directed_phase === 1'b0);
    repeat (TEST_CYCLES) @(posedge clk);
    $display("TB %0s done: pass=%0d fail=%0d", "{{tb_name}}", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
        $display("ALL TESTS PASSED");
    else
        $display("*** %0d TESTS FAILED ***", fail_cnt);
    $display("xbar stats: topology={{topology}} cycles=%0d issued=%0d completed=%0d errors=%0d max_active=%0d contention_cycles=%0d", cycle_count, total_issued, total_completed, total_errors, max_active_masters, contention_cycles);
{% for m in range(n_masters) %}
    $display("master%0d stats: issued=%0d completed=%0d errors=%0d wait_cycles=%0d avg_latency_x100=%0d",
        {{m}}, master_issued[{{m}}], master_completed[{{m}}], master_errors[{{m}}], master_wait_cycles[{{m}}],
        (master_completed[{{m}}] > 0) ? ((100 * master_latency_sum[{{m}}]) / master_completed[{{m}}]) : 0);
{% endfor %}
{% for s in range(n_slaves) %}
    $display("slave%0d stats: ack=%0d err=%0d busy_cycles=%0d utilization_x100=%0d",
        {{s}}, slave_acks[{{s}}], slave_errs[{{s}}], slave_busy_cycles[{{s}}],
        (100 * slave_busy_cycles[{{s}}]) / (cycle_count > 0 ? cycle_count : 1));
{% endfor %}
    $finish;
end
endmodule
""")
    return t.render(
        tb_name=tb_name,
        name=name,
        n_masters=n_masters,
        n_slaves=n_slaves,
        cycles=cycles,
        param_text="\n".join(param_lines),
        choose_cases="\n".join(choose_cases),
        topology=topology,
        d2_slave=d2_slave,
        d3_slave=d3_slave,
        d4_enabled=d4_enabled,
        d4_m0_slave=d4_m0_slave,
        d4_m1_slave=d4_m1_slave
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Wishbone demux, mux, and arbiter modules")
    parser.add_argument('-o', '--output', type=str, help='Output file name (default: stdout)', default=None)
    
    # Add subparsers
    parsers = parser.add_subparsers(dest='command', required=True, help='Sub-command to run')
    

    # Subparser for generating wb_demux
    parser_demux = parsers.add_parser('demux', help='Generate a Wishbone demux')
    parser_demux.add_argument('-n', '--nslaves', type=int, help='Number of slaves in the demux', default=2)
    parser_demux.add_argument('-N', '--name', type=str, help='Name of the generated module', default='Demux_wb')

    # Subparser for generating arbiter core
    parser_arb = parsers.add_parser('arb', help='Generate a generic arbiter')
    parser_arb.add_argument('-n', '--nports', type=int, help='Number of request ports', default=2)
    parser_arb.add_argument('-N', '--name', type=str, help='Name of the generated module', default='Arbiter')
    parser_arb.add_argument('-p', '--policy', type=str, choices=['rr', 'priority'],
                            help='Default arbitration policy parameter', default='priority')
    parser_arb.add_argument('--priority-lsb-high', action='store_true',
                            help='Default fixed-priority direction: bit 0 is highest priority')

    # Subparser for generating wb_mux
    parser_mux = parsers.add_parser('mux', help='Generate a Wishbone mux that instantiates an arbiter')
    parser_mux.add_argument('-m', '--nmasters', type=int, help='Number of masters to arbitrate', default=2)
    parser_mux.add_argument('-N', '--name', type=str, help='Name of the generated module', default='Arbiter_wb')
    parser_mux.add_argument('-A', '--arbiter-name', type=str, help='Name of the instantiated arbiter module', default=None)
    parser_mux.add_argument('-p', '--policy', type=str, choices=['rr', 'priority'],
                               help='Default arbitration policy parameter', default='priority')
    parser_mux.add_argument('--priority-lsb-high', action='store_true',
                               help='Default fixed-priority direction: bit 0 is highest priority')

    # Subparser for generating crossbar
    parser_xbar = parsers.add_parser('xbar', help='Generate a Wishbone crossbar')
    parser_xbar.add_argument('-s', '--nslaves', type=int, help='Number of slave ports', default=2)
    parser_xbar.add_argument('-m', '--nmasters', type=int, help='Number of master ports', default=2)
    parser_xbar.add_argument('-N', '--name', type=str, help='Name of the generated module', default=None)
    parser_xbar.add_argument('-p', '--policy', type=str, choices=['rr', 'priority'],
                               help='Default arbitration policy parameter', default='priority')
    parser_xbar.add_argument('--priority-lsb-high', action='store_true',
                               help='Default fixed-priority direction: bit 0 is highest priority')
    parser_xbar.add_argument('-c', '--connectivity', type=str, help='Connectivity rules (default: "*:*")', default="*:*")
    parser_xbar.add_argument('-t', '--type', type=str, help='Type of crossbar to generate', default="full", choices=["shared", "full"])
    parser_xbar.add_argument('--tb', action='store_true', help='Also append a randomized testbench')
    parser_xbar.add_argument('--tb-cycles', type=int, default=300, help='Randomized testbench cycles')

    args = parser.parse_args()

    with open(args.output, 'w') if args.output else sys.stdout as f:
        if args.command == 'demux':
            f.write(gen_wb_demux(args.nslaves, args.name))
        elif args.command == 'arb':
            pe_name = f"{args.name}_Priority_encoder"
            f.write(gen_priority_encoder(pe_name) + "\n\n")
            f.write(gen_arbiter(args.nports, args.name, pe_name, args.policy, args.priority_lsb_high))
        elif args.command == 'mux':
            arbiter_name = args.arbiter_name if args.arbiter_name else f"Arbiter{args.nmasters}"
            pe_name = f"{arbiter_name}_Priority_encoder"
            f.write(gen_priority_encoder(pe_name) + "\n\n")
            f.write(gen_arbiter(args.nmasters, arbiter_name, pe_name, args.policy, args.priority_lsb_high))
            f.write("\n\n")
            f.write(gen_wb_mux(args.nmasters, args.name, arbiter_name, pe_name, args.policy, args.priority_lsb_high))
        elif args.command == 'xbar':
            name = args.name if args.name else 'Xbar_wb'
            if args.type == 'shared':
                f.write(gen_xbar_shared(name, args.nmasters, args.nslaves, args.policy, args.priority_lsb_high))
                tb_conn = {m: list(range(args.nslaves)) for m in range(args.nmasters)}
            else:
                conn_matrix = parse_connectivity(args.connectivity, args.nmasters, args.nslaves)
                print_connectivity_matrix(conn_matrix)
                f.write(gen_xbar_full(name, args.nmasters, args.nslaves, conn_matrix, args.policy, args.priority_lsb_high))
                f.write("\n")
                tb_conn = conn_matrix
            if args.tb:
                f.write("\n")
                f.write(gen_tb_xbar(name, args.nmasters, args.nslaves, conn=tb_conn, cycles=args.tb_cycles, topology=args.type))

        else:
            print("Unknown command: {0}".format(args.command))
