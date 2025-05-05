package orion_types;
////////////////////////////////////////////////////////////////////////////////
// Parameters
parameter XLEN      = 32;       // Width of the registers
parameter ADDRW     = 32;       // Width of the address bus
parameter DATAW     = 32;       // Width of the data bus

parameter MASKW     = DATAW/8;  // Width of the mask

parameter NUM_REGS  = 32;
parameter RF_IDX_BITS = $clog2(NUM_REGS);

////////////////////////////////////////////////////////////////////////////////
// Features

`ifdef EN_RV32M_EXT
parameter EN_RV32M_EXT = 1; // Enable RV32M extension
`else
parameter EN_RV32M_EXT = 0; // Disable RV32M extension
`endif


////////////////////////////////////////////////////////////////////////////////
// Types
typedef enum logic [6:0] {
    OP_LUI   = 7'b0110111, // load upper immediate (U-type)
    OP_AUIPC = 7'b0010111, // add upper immediate to pc (U-type)
    OP_JAL   = 7'b1101111, // jump and link (J-type)
    OP_JALR  = 7'b1100111, // jump and link register (I-type)
    OP_BRANCH= 7'b1100011, // branch (B-type)
    OP_LOAD  = 7'b0000011, // load (I-type)
    OP_STORE = 7'b0100011, // store (S-type)
    OP_IMM   = 7'b0010011, // immediate (I-type)
    OP_REG   = 7'b0110011, // register (R-type)
    OP_SYSTEM= 7'b1110011  // system (I-type)
} opcode_t;

typedef enum logic [2:0] {
    FUNCT3_ADD  = 3'b000, // check func7 for add/sub
    FUNCT3_SLL  = 3'b001,
    FUNCT3_SLT  = 3'b010,
    FUNCT3_SLTU = 3'b011,
    FUNCT3_XOR  = 3'b100,
    FUNCT3_SR   = 3'b101, // check func7 for logical/arithmetic shift
    FUNCT3_OR   = 3'b110,
    FUNCT3_AND  = 3'b111
} funct3_arith_t;

typedef enum logic [2:0] {
    ALU_OP_ADD  = 3'b000,
    ALU_OP_SUB  = 3'b001,
    ALU_OP_SLL  = 3'b010,
    ALU_OP_XOR  = 3'b011,
    ALU_OP_SRL  = 3'b100,
    ALU_OP_SRA  = 3'b101,
    ALU_OP_OR   = 3'b110,
    ALU_OP_AND  = 3'b111
} alu_ops_t;

typedef enum logic [1:0] {
    ALU_SEL_A_RS1  = 2'b00,
    ALU_SEL_A_PC   = 2'b01,
    ALU_SEL_A_ZERO = 2'b10
} alu_sel_a_t;

typedef enum logic [2:0] {
    CMP_OP_EQ   = 3'b000,
    CMP_OP_NEQ  = 3'b001,
    CMP_OP_LT   = 3'b100,
    CMP_OP_GE   = 3'b101,
    CMP_OP_LTU  = 3'b110,
    CMP_OP_GEU  = 3'b111  
} cmp_ops_t;

typedef enum logic [2:0] {
    MUL_OP_MUL    = 3'b000, 
    MUL_OP_MULH   = 3'b001,
    MUL_OP_MULHSU = 3'b010,
    MUL_OP_MULHU  = 3'b011,
    MUL_OP_DIV    = 3'b100,
    MUL_OP_DIVU   = 3'b101, 
    MUL_OP_REM    = 3'b110,
    MUL_OP_REMU   = 3'b111
} mul_ops_t;

typedef enum logic [1:0] {
    SEL_ALU_OUT     = 2'b00,
    SEL_CMP_OUT     = 2'b01,
    SEL_MUL_OUT     = 2'b10,
    SEL_PC_NEXT     = 2'b11
}  ex_mux_sel_t;

typedef enum logic [2:0] {
    FUNCT3_LS_B   = 3'b000,
    FUNCT3_LS_H   = 3'b001,
    FUNCT3_LS_W   = 3'b010,
    FUNCT3_LS_BU  = 3'b100, // Only for load
    FUNCT3_LS_HU  = 3'b101  // Only for load
} funct3_load_store_t;


/// CSR EXTENSION
typedef enum logic [2:0] {
    FUNCT3_CSRRW  = 3'b001,
    FUNCT3_CSRRS  = 3'b010,
    FUNCT3_CSRRC  = 3'b011,
    FUNCT3_CSRRWI = 3'b101,
    FUNCT3_CSRRSI = 3'b110,
    FUNCT3_CSRRCI = 3'b111
} funct3_csr_t;

typedef enum logic [1:0] {
    CSR_OP_RW  = 2'b01,
    CSR_OP_RS  = 2'b10,
    CSR_OP_RC  = 2'b11
} csr_ops_t;

typedef enum logic [2:0] {
    IMM_SEL_I = 3'b000, // Immediate is I-type
    IMM_SEL_S = 3'b001, // Immediate is S-type
    IMM_SEL_B = 3'b010, // Immediate is B-type
    IMM_SEL_U = 3'b011, // Immediate is U-type
    IMM_SEL_J = 3'b100  // Immediate is J-type
} imm_sel_t;



typedef enum logic [11:0] {
    // Unprivileged Counter/Timers
    CSR_CYCLE           = 12'hC00,     // Cycle counter for RDCYCLE instruction.
    // CSR_TIME            = 12'hC01     // Timer for RDTIME instruction.
    CSR_INSTRET         = 12'hC02,     // Instructions-retired counter for RDINSTRET instruction.
    // CSR_HPMCOUNTER3     = 12'hC03     // Performance-monitoring counter.
    // CSR_HPMCOUNTER4     = 12'hC04     // Performance-monitoring counter.
    // CSR_HPMCOUNTER31    = 12'hC1F     // Performance-monitoring counter.
    CSR_CYCLEH          = 12'hC80,     // Upper 32 bits of cycle, RV32 only.
    // CSR_TIMEH           = 12'hC81     // Upper 32 bits of time, RV32 only.
    CSR_INSTRETH        = 12'hC82,     // Upper 32 bits of instret, RV32 only.
    // CSR_HPMCOUNTER3H    = 12'hC83     // Upper 32 bits of hpmcounter3, RV32 only.
    // CSR_HPMCOUNTER4H    = 12'hC84     // Upper 32 bits of hpmcounter4, RV32 only.
    // CSR_HPMCOUNTER31H   = 12'hC9F     // Upper 32 bits of hpmcounter31, RV32 only.

    // Machine information registers
    // CSR_MVENDORID       = 12'hF11     // Vendor ID
    // CSR_MARCHID         = 12'hF12     // Architecture ID.
    // CSR_MIMPID          = 12'hF13     // Implementation ID.
    // CSR_MHARTID         = 12'hF14     // Hardware thread ID.
    // CSR_MCONFIGPTR      = 12'hF15     // Pointer to configuration data structure.

    // Machine Trap Setup
    // CSR_MSTATUS         = 12'h300     // Machine status register.
    // CSR_MISA            = 12'h301     // ISA and extensions
    // CSR_MEDELEG         = 12'h302     // Machine exception delegation register.
    // CSR_MIDELEG         = 12'h303     // Machine interrupt delegation register.
    // CSR_MIE             = 12'h304     // Machine interrupt-enable register.
    // CSR_MTVEC           = 12'h305     // Machine trap-handler base address.
    // CSR_MCOUNTEREN      = 12'h306     // Machine counter enable.
    // CSR_MSTATUSH        = 12'h310     // Additional machine status register, RV32 only.

    // Machine Trap Handling
    // CSR_MSCRATCH        = 12'h340     // Scratch register for machine trap handlers.
    // CSR_MEPC            = 12'h341     // Machine exception program counter.
    // CSR_MCAUSE          = 12'h342     // Machine trap cause.
    // CSR_MTVAL           = 12'h343     // Machine bad address or instruction.
    // CSR_MIP             = 12'h344     // Machine interrupt pending.
    // CSR_MTINST          = 12'h34A     // Machine trap instruction (transformed).
    // CSR_MTVAL2          = 12'h34B     // Machine bad guest physical address.

    // Machine Counter/Timers
    CSR_MCYCLE          = 12'hB00,     // Machine cycle counter.
    CSR_MINSTRET        = 12'hB02,     // Machine instructions-retired counter.
    // CSR_MHPMCOUNTER3    = 12'hB03     // Machine performance-monitoring counter.
    // CSR_MHPMCOUNTER4    = 12'hB04     // Machine performance-monitoring counter.
    // CSR_MHPMCOUNTER31   = 12'hB1F     // Machine performance-monitoring counter.
    CSR_MCYCLEH         = 12'hB80,     // Upper 32 bits of mcycle, RV32 only.
    CSR_MINSTRETH       = 12'hB82     // Upper 32 bits of minstret, RV32 only.
    // CSR_MHPMCOUNTER3H   = 12'hB83     // Upper 32 bits of mhpmcounter3, RV32 only.
    // CSR_MHPMCOUNTER4H   = 12'hB84     // Upper 32 bits of mhpmcounter4, RV32 only.
    // CSR_MHPMCOUNTER31H  = 12'hB9F     // Upper 32 bits of mhpmcounter31, RV32 only.

    // Machine Counter Setup
    // CSR_MCOUNTINHIBIT   = 12'h320     // Machine counter-inhibit register.
    // CSR_MHPMEVENT3      = 12'h323     // Machine performance-monitoring event selector.
    // CSR_MHPMEVENT4      = 12'h324     // Machine performance-monitoring event selector.
    // CSR_MHPMEVENT31     = 12'h33F     // Machine performance-monitoring event selector.

    // Debug/Trace Registers (shared with Debug Mode)
    // CSR_TSELECT         = 12'h7A0     // Debug/Trace trigger register select.
    // CSR_TDATA1          = 12'h7A1     // First Debug/Trace trigger data register.
    // CSR_TDATA2          = 12'h7A2     // Second Debug/Trace trigger data register.
    // CSR_TDATA3          = 12'h7A3     // Third Debug/Trace trigger data register.
    // CSR_MCONTEXT        = 12'h7A8     // Machine-mode context register.

    // Debug Mode Registers
    // CSR_DCSR            = 12'h7B0     // Debug control and status register.
    // CSR_DPC             = 12'h7B1     // Debug PC.
    // CSR_DSCRATCH0       = 12'h7B2     // Debug scratch register 0.
    // CSR_DSCRATCH1       = 12'h7B3     // Debug scratch register 1.
} csr_addr_t;


////////////////////////////////////////////////////////////////////////////////
// Interfaces

// Cache
// interface cache_if #(
//     parameter ADDRW = 32,
//     parameter DATAW = 32
// );
//     logic [ADDRW-1:0]   addr;
//     logic               valid;
//     logic [DATAW-1:0]   rdata;
//     logic [DATAW-1:0]   wdata;
//     logic [DATAW/8-1:0] mask;
//     logic               we;
//     logic               ack;

//     modport master (
//         output addr,
//         output valid,
//         input  rdata,
//         output wdata,
//         output mask,
//         output we,
//         input  ack
//     );

//     modport slave (
//         input  addr,
//         input  valid,
//         output rdata,
//         input  wdata,
//         input  mask,
//         input  we,
//         output ack
//     );
// endinterface



typedef struct packed {
    logic [XLEN-1:0]        pc;
    logic [XLEN-1:0]        instr;
    logic [RF_IDX_BITS-1:0] rs1_s;
    logic [RF_IDX_BITS-1:0] rs2_s;
    logic [RF_IDX_BITS-1:0] rd_s;
    logic [XLEN-1:0]        rs1_v;
    logic [XLEN-1:0]        rs2_v;
    logic [XLEN-1:0]        rd_v;
    logic                   rd_we;
    logic [ADDRW-1:0]       mem_addr;      
    logic [MASKW-1:0]       mem_rmask;   
    logic [MASKW-1:0]       mem_wmask;      
    logic [XLEN-1:0]        mem_rdata;      
    logic [XLEN-1:0]        mem_wdata;     
} debug_t;



typedef struct packed {
    logic                   valid;
    logic [XLEN-1:0]        pc;
    logic [DATAW-1:0]       instr; 
} if_id_t; 

typedef struct packed {
    logic                   valid;
    logic [XLEN-1:0]        pc;
    logic [XLEN-1:0]        rs1_v;
    logic [XLEN-1:0]        rs2_v;
    logic [XLEN-1:0]        imm;
    logic [RF_IDX_BITS-1:0] rd_s;
    logic                   rd_we;
    alu_ops_t               alu_op;
    cmp_ops_t               cmp_op;
    mul_ops_t               mul_op;
    alu_sel_a_t             alu_sel_a;
    logic                   alu_sel_b_imm;
    logic                   cmp_sel_b_imm;
    ex_mux_sel_t            ex_mux_sel;
    funct3_load_store_t     ld_str_type;
    logic                   is_load;    
    logic                   is_store;
    logic                   is_jump;
    logic                   is_jump_conditional;

    logic                   is_csr_op;
    logic                   csr_ren;
    logic                   csr_wen;
    csr_ops_t               csr_op;
    logic [XLEN-1:0]        csr_operand;

    debug_t                 debug;
} id_ex_t;



typedef struct packed {
    logic                   jump_en;
    logic [XLEN-1:0]        jump_addr;            
} ex_if_t;

typedef struct packed {
    logic                   valid;
    logic                   rd_we;
    logic [RF_IDX_BITS-1:0] rd_s;
    logic [XLEN-1:0]        rd_v;
    logic                   is_load;    
} ex_id_t;

typedef struct packed {
    logic                   valid;
    logic [RF_IDX_BITS-1:0] rd_s;
    logic                   rd_we;
    logic [XLEN-1:0]        rd_v;
    funct3_load_store_t     ld_str_type;
    logic                   is_load;    
    logic                   is_store;

    logic                   is_csr_op;
    logic                   csr_ren;
    logic                   csr_wen;
    logic [11:0]            csr_addr;
    csr_ops_t               csr_op;
    logic [XLEN-1:0]        csr_operand;

    debug_t                 debug;
} ex_mem_t;


typedef struct packed {
    logic                   valid;
    logic                   rd_we;
    logic [RF_IDX_BITS-1:0] rd_s;
    logic [XLEN-1:0]        rd_v;
} mem_id_t;

typedef struct packed {
    logic                   valid;
    logic [RF_IDX_BITS-1:0] rd_s;
    logic                   rd_we;
    logic [XLEN-1:0]        rd_v;

    logic                   is_csr_op;

    debug_t                 debug;
} mem_wb_t;

typedef struct packed {
    logic                   rd_we;
    logic [XLEN-1:0]        rd_v;
    logic [RF_IDX_BITS-1:0] rd_s;
} wb_id_t;


typedef struct packed {
    logic [11:0]        addr;
    logic [XLEN-1:0]    operand;
    csr_ops_t           op;
    logic               ren;
    logic               wen;
} mem_csrf_t;

typedef struct packed {
    logic  [XLEN-1:0]  rd_v;
} csrf_wb_t;

typedef struct packed {
    logic  instr_retired;
} wb_csrf_t;
endpackage
