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
    OP_REG   = 7'b0110011 // register (R-type)
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

typedef enum logic [1:0] {
    SEL_ALU_OUT     = 2'b00,
    SEL_CMP_OUT     = 2'b01,
    SEL_PC_NEXT     = 2'b11
}  ex_mux_sel_t;


typedef enum logic [2:0] {
    FUNCT3_LS_B   = 3'b000,
    FUNCT3_LS_H   = 3'b001,
    FUNCT3_LS_W   = 3'b010,
    FUNCT3_LS_BU  = 3'b100, // Only for load
    FUNCT3_LS_HU  = 3'b101  // Only for load
} funct3_load_store_t;




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
    alu_sel_a_t             alu_sel_a;
    logic                   alu_sel_b_imm;
    logic                   cmp_sel_b_imm;
    ex_mux_sel_t            ex_mux_sel;
    funct3_load_store_t     ld_str_type;
    logic                   is_load;    
    logic                   is_store;
    logic                   is_jump;
    logic                   is_jump_conditional;

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

    debug_t                 debug;
} mem_wb_t;



typedef struct packed {
    logic                   rd_we;
    logic [XLEN-1:0]        rd_v;
    logic [RF_IDX_BITS-1:0] rd_s;
} wb_id_t;

endpackage
