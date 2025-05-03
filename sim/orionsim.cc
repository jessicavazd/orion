#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <fstream>

#include "argparse.h"
#include "testbench.h"

#include "Vorion_soc_headers.h"

#define MAX_SIM_IITERATIONS 10000000

// Get/Set/Clr bits in a word
#define BIT_GET(x, n)           ((x) & (1 << (n)))
#define BIT_SET(x, n, v)        ((v) ? ((x) | (1 << (n))) : ((x) & ~(1 << (n))))

// Get/Set clear bitfields in a word (word[n:m])
#define GET_MASK(n, m)          (((1 << ((n) - (m) + 1)) - 1) << (m)) 
#define BITS_GET(x, n, m)       ((GET_MASK(n, m) & (x)) >> (m))
#define BITS_SET(x, n, m, v)    (GET_MASK(n, m) & ((v) << (m)) | ((x) & ~GET_MASK(n, m)))

#define MEM_ADDR 0x00010000
#define MEM_SIZE (64*1024)  // 64KB

/*
    VDEV (Virtual Devices)
    ======================
    Set of 8 registers to interact with the simulator

    -------+-----------+-------------------------------------------------
    Offset | Name      | Description
    -------+-----------+-------------------------------------------------
    0x00   | CONSOLE   | Console register (console input/output) 
    0x04   | reserved  | --
    0x08   | CYCLE     | CYCLE register low-word  (64-bit cycle counter)
    0x0C   | CYCLE_HI  | CYCLE high-word
    0x10   | INSTRET   | INSTRET low-word (64-bit instruction retired counter)
    0x14   | INSTRET_HI| INSTRET high-word
    0x18   | reserved  | --
    0x1C   | SIMCTRL   | Simulation control register
    -------+-----------+-------------------------------------------------

    Register Description
    =======================
    0x00: CONSOLE
        CONSOLE[7:0]:   Tx data
        CONSOLE[15:8]:  Rx data
        CONSOLE[16]:    Tx valid
        CONSOLE[17]:    Rx valid

    0x08: CYCLE
        CYCLE[31:0]:    Low word of cycle counter

    0x0C: CYCLE_HI
        CYCLE_HI[31:0]: High word of cycle counter

    0x10: INSTRET
        INSTRET[31:0]:  Low word of instruction retired counter

    0x14: INSTRET_HI
        INSTRET_HI[31:0]: High word of instruction retired counter

    0x1C: SIMCTRL
        SIMCTRL[7:0]:   Return code
        SIMCTRL[8]:     Finish request
*/

#define VDEV_ADDR               MEM_ADDR + MEM_SIZE - 0x20
#define VDEV_SIZE               0x20

#define VDEV_CONSOLE_ADDR       VDEV_ADDR + 0x00 // Console register
#define VDEV_CYCLE_ADDR         VDEV_ADDR + 0x08 // CYCLE register low-word
#define VDEV_CYCLE_ADDR_HI      VDEV_ADDR + 0x0C // CYCLE register high-word
#define VDEV_INSTRET_ADDR       VDEV_ADDR + 0x10 // INSTRET register low-word
#define VDEV_INSTRET_ADDR_HI    VDEV_ADDR + 0x14 // INSTRET register high-word
#define VDEV_SIMCTRL_ADDR       VDEV_ADDR + 0x1C // SIMCTRL register


#define RESET_CYCLES 2

// Logging //////////
enum verbosity_t {ALL=3, DEFAULT=2, ERRORS=1, NONE=0};
verbosity_t verbosity = DEFAULT;

#define SIMLOG(x, ...)  if(verbosity >= DEFAULT) printf("[+] " x, ##__VA_ARGS__)
#define SIMWARN(x, ...) if(verbosity >= DEFAULT) printf("[!] " x, ##__VA_ARGS__)
#define SIMERR(x, ...)  if(verbosity >= ERRORS) printf("[ERROR] " x, ##__VA_ARGS__)
#define LOG(x)  if(verbosity >= DEFAULT) {x}
#define WARN(x) if(verbosity >= DEFAULT) {x}
#define ERR(x)  if(verbosity >= ERRORS) {x}
/////////////////////


#ifdef TRACE_FST
    #define TRACE_FILE "trace.fst"
    #define TRACE_TYPE_STR "FST"
#else
    #define TRACE_FILE "trace.vcd"
    #define TRACE_TYPE_STR "VCD"
#endif

std::string banner = 
"  ____       _              _____ _\n"
" / __ \\     (_)            / ____(_)\n"
"| |  | |_ __ _  ___  _ __ | (___  _ _ __ ___\n"
"| |  | | '__| |/ _ \\| '_ \\ \\___ \\| | '_ ` _ \\ \n"
"| |__| | |  | | (_) | | | |____) | | | | | | |\n"
" \\____/|_|  |_|\\___/|_| |_|_____/|_|_| |_| |_|\n"
"==================================================\n";

std::string get_masked_hexstr(uint32_t data, uint8_t mask) {
    char buf[9] = {}; // Up to 4 bytes * 2 hex digits = 8 + null terminator
    int offset = 0;
    for (int i = 3; i >= 0; i--) {  // MSB to LSB
        if (mask & (1 << i)) {
            uint8_t byte = (data >> (i * 8)) & 0xFF;
            offset += std::sprintf(buf + offset, "%02x", byte);
        }
    }
    return std::string(buf);
}

enum Term_cause_t {
    TERM_CAUSE_UNKNOWN,     // Unknown termination cause
    TERM_CAUSE_FINISH,      // $finish called from RTL
    TERM_CAUSE_MAX_CYCLES,  // Reached maximum cycles
    TERM_CAUSE_TERM_REQ     // Termination request from software
};

class OrionSim {
public:
    OrionSim() {
        // Initialize the simulator
        LOG(printf("%s", banner.c_str());)
        
        SIMLOG("Initializing simulator\n");
        SIMLOG("Memory map:\n");
        SIMLOG(" - RAM : 0x%08x (0x%x B)\n", MEM_ADDR, MEM_SIZE);
        SIMLOG(" - VDEV: 0x%08x (0x%x)\n", VDEV_ADDR, VDEV_SIZE);
     
        tb = new Testbench<Vorion_soc>();
        tb->register_clk((bool*)&tb->dut_->clk_i);
        tb->register_rst((bool*)&tb->dut_->rst_i);

        // Setup scope pointers
        signal_ptrs.instr_valid = (bool*)&tb->dut_->orion_soc->core->writeback_stg->dbg_valid;
        signal_ptrs.instr       = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_instr;
        signal_ptrs.pc          = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_pc;
        signal_ptrs.rs1_s       = (uint8_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rs1_s;
        signal_ptrs.rs2_s       = (uint8_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rs2_s;
        signal_ptrs.rd_s        = (uint8_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rd_s;
        signal_ptrs.rs1_v       = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rs1_v;
        signal_ptrs.rs2_v       = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rs2_v;
        signal_ptrs.rd_v        = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rd_v;
        signal_ptrs.rd_we       = (bool*)&tb->dut_->orion_soc->core->writeback_stg->dbg_rd_we;
        signal_ptrs.mem_addr    = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_mem_addr;
        signal_ptrs.mem_rmask   = (uint8_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_mem_rmask;
        signal_ptrs.mem_wmask   = (uint8_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_mem_wmask;
        signal_ptrs.mem_rdata   = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_mem_rdata;
        signal_ptrs.mem_wdata   = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_mem_wdata;

        // Clear vdev registers
        for(int addr = VDEV_ADDR; addr < (VDEV_ADDR + VDEV_SIZE); addr+=4) {
            unsigned mem_index = (addr - MEM_ADDR) / 4;
            tb->dut_->orion_soc->memory->mem[mem_index] = 0x00000000;
        }
    }

    ~OrionSim() {
        // If trace is open, close it
        if(log_f) {
            fclose(log_f);
            SIMLOG("Closed trace file\n");
        }

        // Clean up the simulator
        delete tb;
    }

    void eval_vdev() {
        // Evaluate the VDEV registers

        // SIMUART
        if((*signal_ptrs.instr_valid & 0x1) && 
            (*signal_ptrs.mem_wmask & 0x1) &&
            (*signal_ptrs.mem_addr == VDEV_CONSOLE_ADDR)) {
                putchar(*signal_ptrs.mem_wdata & 0xFF);
                fflush(stdout);
        }

        // // Console register (TX)
        // if(BIT_GET(tb->dut_->orion_soc->memory->mem[(VDEV_CONSOLE_ADDR - MEM_ADDR)/4], 16)) {
        //     // DEBUG

        //     uint8_t tx_data = BITS_GET(tb->dut_->orion_soc->memory->mem[(VDEV_CONSOLE_ADDR - MEM_ADDR)/4], 7, 0);
        //     putchar(tx_data);
        //     fflush(stdout);

        //     // Clear TX valid bit
        //     tb->dut_->orion_soc->memory->mem[(VDEV_CONSOLE_ADDR - MEM_ADDR)/4] = 
        //         BIT_SET(tb->dut_->orion_soc->memory->mem[(VDEV_CONSOLE_ADDR - MEM_ADDR)/4], 16, 0);
        // }

        // TODO: Console register (RX)

        // Cycle register
        uint64_t cycles = tb->get_cycles();
        tb->dut_->orion_soc->memory->mem[(VDEV_CYCLE_ADDR    - MEM_ADDR)/4] = (uint32_t)cycles;
        tb->dut_->orion_soc->memory->mem[(VDEV_CYCLE_ADDR_HI - MEM_ADDR)/4] = (uint32_t)(cycles >> 32);

        // Instruction retired register
        tb->dut_->orion_soc->memory->mem[(VDEV_INSTRET_ADDR    - MEM_ADDR)/4] = (uint32_t)instret;
        tb->dut_->orion_soc->memory->mem[(VDEV_INSTRET_ADDR_HI - MEM_ADDR)/4] = (uint32_t)(instret >> 32);
        
        // Simulation control register
        uint32_t simctrl = tb->dut_->orion_soc->memory->mem[(VDEV_SIMCTRL_ADDR - MEM_ADDR)/4];
        if(BIT_GET(simctrl, 8)) {
            term_req = true;
            sw_ret_code = BITS_GET(simctrl, 7, 0);
            tb->dut_->orion_soc->memory->mem[(VDEV_SIMCTRL_ADDR - MEM_ADDR)/4] = 
                BIT_SET(tb->dut_->orion_soc->memory->mem[(VDEV_SIMCTRL_ADDR - MEM_ADDR)/4], 8, 0);
        }
    }


    int run() {
        // Run the simulation
        SIMLOG("Starting simulation\n");

        SIMLOG("Resetting SoC\n");
        tb->reset(RESET_CYCLES);

        LOG(printf("----------------------------------------\n");)

        // Tick the simulation
        while(1) {
            if(tb->finished()) {
                term_pc = *signal_ptrs.pc;
                term_cause = TERM_CAUSE_FINISH;
                break;
            }

            if(tb->get_cycles() >= max_cycles) {
                term_pc = *signal_ptrs.pc;
                term_cause = TERM_CAUSE_MAX_CYCLES;
                break;
            }
            
            if(term_req) {
                term_pc = *signal_ptrs.pc;
                term_cause = TERM_CAUSE_TERM_REQ;
                break;
            }
            
            // Evaluate the VDEV registers
            eval_vdev();

            // Tick clock once
            tb->tick();

            // Dump log
            if(log_f) {
                sim_log();
            }
            
            // Increment the instruction retired counter
            if (*signal_ptrs.instr_valid & 0x1) {
                instret++;
            }
        }

        LOG(printf("----------------------------------------\n");)
        SIMLOG("Instructions executed: %lu\n", instret);
        SIMLOG("IPC: %.6f\n", (float)instret/(float)tb->get_cycles());
        SIMLOG("Cycles: %lu (Time: %lu ps)\n", tb->get_cycles(), tb->get_time());       
        SIMLOG("Simulation finished @ PC: 0x%08x)\n", term_pc);

        // Check for termination cause
        int rv = 0;
        switch(term_cause) {
            case TERM_CAUSE_FINISH:
                SIMLOG("  $finish called from RTL\n");
                rv = 1;
                break;
            case TERM_CAUSE_MAX_CYCLES:
                SIMLOG("  Reached maximum cycles (%lu)\n", max_cycles);
                rv = 1;
                break;
            case TERM_CAUSE_TERM_REQ:
                SIMLOG("  Termination request from software (retcode: %d)\n", sw_ret_code);
                rv = sw_ret_code;
                break;
            default:
                SIMLOG("  Unknown termination cause\n");
                rv = -1;
                break;
        }
        return rv;
    }

    void open_trace(const std::string &filename) {
        // Open the trace file
        SIMLOG("Opening trace file: %s\n", filename.c_str());
        tb->open_trace(filename);
    }

    void load_hex(const std::string &filename) {
        // Load the hex file
        SIMLOG("Loading hex file: %s\n", filename.c_str());
        std::ifstream hex_file(filename);
        if(!hex_file.is_open()) {
            fprintf(stderr, "Error: Could not open hex file: %s\n", filename.c_str());
            return;
        }

        std::string line;
        uint32_t addr = 0x0000000;          // Local to memory
        uint64_t nbytes_written = 0;

        while(std::getline(hex_file, line)) {
            if(line.empty()) continue;
            
            // Update address if line starts with '@'
            if(line[0] == '@') {
                std::runtime_error("Address parsing not implemented");
                // addr = std::stoul(line.substr(1, line.size() - 1), nullptr, 16);
                continue;
            }

            // Parse the data line
            uint32_t data = std::stoul(line, nullptr, 16);
            
            // Check if the address is within the valid range
            if(!(/*addr >= MEM_ADDR || */  addr < /*MEM_ADDR +*/ MEM_SIZE)) {
                fprintf(stderr, "Error: Address out of range: 0x%08X\n", addr);
                fprintf(stderr, "       Memory Initializatioin failed");
                exit(1);
            }
            
            // Write the data word to the memory
            uint32_t memory_word_index = (addr /*- MEM_ADDR*/) / 4;
            tb->dut_->orion_soc->memory->mem[memory_word_index] = data;
            addr += 4;
            nbytes_written += 4;
        }

        hex_file.close();
        SIMLOG("Loaded %lu bytes in memory\n", nbytes_written);
    }

    void dump_mem(std::string filename) {
        SIMLOG("Dumping memory to file: %s\n", filename.c_str());
        std::ofstream dump_file(filename, std::ios::binary);
        if(!dump_file.is_open()) {
            fprintf(stderr, "Error: Could not open dump file: %s\n", filename.c_str());
            return;
        }
        for(uint32_t word_indx = 0; word_indx < MEM_SIZE / 4; word_indx++) {
            uint32_t data = tb->dut_->orion_soc->memory->mem[word_indx];
            dump_file << std::hex << std::setw(8) << std::setfill('0') << data << "\n";
        }
        dump_file.close();
    }

    void set_max_cycles(uint64_t cycles) {
        // Set the maximum number of cycles
        SIMLOG("Setting maximum cycles to: %lu\n", cycles);
        max_cycles = cycles;
    }

    void sim_log() {
        if (log_format == "spike") {
            if(! *signal_ptrs.instr_valid) {
                return; // skip bubbles
            }
            /*
            Spike format:
                default:    core  {core_id}: <priv> <pc> (<instr>)
                reg update: core  {core_id}: <priv> <pc> (<instr>) <rd> <new_value>
                store;      core  {core_id}: <priv> <pc> (<instr>) mem <store_target_address> <data_to_store>
                load;       core  {core_id}: <priv> <pc> (<instr>) rd <loaded_data> mem <load_target_address>
            */
            fprintf(log_f, "core   0: 3 0x%08x (0x%08x)", *signal_ptrs.pc, *signal_ptrs.instr);
            if(*signal_ptrs.mem_rmask & 0xf) {
                // rd <loaded_data> mem <load_target_address>
                fprintf(log_f, " x%-2d 0x%08x mem 0x%08x", *signal_ptrs.rd_s & 0x1f, *signal_ptrs.mem_rdata, *signal_ptrs.mem_addr);
            }
            else if(*signal_ptrs.mem_wmask & 0xf) {
                // mem <store_target_address> <data_to_store>
                fprintf(log_f, " mem 0x%08x 0x%s", *signal_ptrs.mem_addr, get_masked_hexstr(*signal_ptrs.mem_wdata, *signal_ptrs.mem_wmask).c_str());
            }
            else if((*signal_ptrs.rd_we & 0x1) && ((*signal_ptrs.rd_s & 0x1f) != 0)) {
                fprintf(log_f, " x%-2d 0x%08x", *signal_ptrs.rd_s & 0x1f, *signal_ptrs.rd_v);
            } 
            
        } else {
            fprintf(log_f, "[%8lu] %s ", tb->get_cycles(), *signal_ptrs.instr_valid ? "       " : "INVALID");
            fprintf(log_f, "PC: 0x%08x, Instr: 0x%08x, ", *signal_ptrs.pc, *signal_ptrs.instr);
            fprintf(log_f, "rd: (x%-2d: 0x%08x, we: %d), ", *signal_ptrs.rd_s & 0x1f, *signal_ptrs.rd_v, *signal_ptrs.rd_we);
            fprintf(log_f, "rs1: (x%-2d: 0x%08x), ", *signal_ptrs.rs1_s & 0x1f, *signal_ptrs.rs1_v);
            fprintf(log_f, "rs2: (x%-2d: 0x%08x) ", *signal_ptrs.rs2_s & 0x1f, *signal_ptrs.rs2_v);
        }
        fprintf(log_f, "\n");
        fflush(log_f);
    }

    void open_log(const std::string &filename) {
        // Open the simulation log file
        SIMLOG("Opening simulation log file: %s\n", filename.c_str());
        log_f = fopen(filename.c_str(), "w");
        if(!log_f) {
            fprintf(stderr, "Error: Could not open sim log file: %s\n", filename.c_str());
            return;
        }
    }

    void set_log_format(const std::string &format) {
        // Set the log format
        SIMLOG("Setting log format to: %s\n", format.c_str());
        if(format == "spike") {
            log_format = "spike";
        } else if(format == "default") {
            log_format = "default";
        } else {
            fprintf(stderr, "Error: Unknown log format: %s\n", format.c_str());
            return;
        }
    }

private:
    Testbench<Vorion_soc> *tb;
    uint64_t max_cycles = MAX_SIM_IITERATIONS;

    // Retired instruction counter
    uint64_t instret = 0;
    
    // Simulation control
    bool         term_req    = false;
    uint32_t     term_pc     = 0;
    Term_cause_t term_cause  = TERM_CAUSE_UNKNOWN;
    int          sw_ret_code = 0;

    // Signal pointers
    struct {
        bool *instr_valid;
        uint32_t *instr;
        uint32_t *pc;
        uint8_t *rs1_s;
        uint8_t *rs2_s;
        uint8_t *rd_s;
        uint32_t *rs1_v;
        uint32_t *rs2_v;
        uint32_t *rd_v;
        bool *rd_we;
        uint32_t *mem_addr;
        uint8_t *mem_rmask;
        uint8_t *mem_wmask;
        uint32_t *mem_rdata;
        uint32_t *mem_wdata;
    } signal_ptrs;

    FILE *log_f = nullptr;
    std::string log_format = "default";
};



int main(int argc, char** argv) {
    // Parse Arguments
    ArgParse::ArgumentParser parser("orionsim", "RTL simulator for the OrionSoC");
    parser.add_argument({"-m", "--max-cycles"}, "Maximum number of cycles to simulate", ArgParse::ArgType_t::INT);
    parser.add_argument({"-t", "--trace"}, "Enable trace", ArgParse::ArgType_t::BOOL, "false");
    parser.add_argument({"--trace-file"}, "Specify a trace file (Trace type: " TRACE_TYPE_STR ")", ArgParse::ArgType_t::STR, TRACE_FILE);
    parser.add_argument({"-l", "--log"}, "Enable simulation log", ArgParse::ArgType_t::STR);
    parser.add_argument({"-v", "--verbosity"}, "Set verbosity (ALL=3, DEFAULT=2, ERRORS=1, NONE=0)", ArgParse::ArgType_t::INT);
    parser.add_argument({"--log-format"}, "Specify log format (choices: spike, default)", ArgParse::ArgType_t::STR);
    parser.add_argument({"--dump-mem"}, "Dump memory contents to a file after simulation finishes", ArgParse::ArgType_t::STR);

    if(parser.parse_args(argc, argv) != 0) {
        return 1;
    }
    auto opt_args = parser.get_opt_args();
    auto pos_args = parser.get_pos_args();

    // Set print verbosity
    if(opt_args.count("verbosity") > 0) {
        verbosity_t verb = (verbosity_t)opt_args["verbosity"].value.as_int;
        if (!(verb >= NONE && verb < ALL)) {
            SIMERR("Invalid verbosity value: %d\n", verb);
            return 1;
        }
        verbosity = verb;
    }

    // Create the simulator instance
    OrionSim sim;

    // Open trace file
    if(opt_args["trace"].value.as_bool) {
        std::string trace_file = opt_args["trace_file"].value.as_str;
        sim.open_trace(trace_file);
    }

    // Enable simulation log
    if(opt_args.count("log") > 0) {
        std::string log_file = opt_args["log"].value.as_str;
        sim.open_log(log_file);
    }

    // Set log format
    if(opt_args.count("log_format") > 0) {
        std::string log_format = opt_args["log_format"].value.as_str;
        sim.set_log_format(log_format);
    }  

    // Set maximum cycles
    if(opt_args.count("max_cycles") > 0) {
        uint64_t max_cycles = (uint64_t) opt_args["max_cycles"].value.as_int;
        sim.set_max_cycles(max_cycles);
    }

    // Load the program file
    if(pos_args.size() > 0) {
        std::string hex_file = pos_args[0];
        sim.load_hex(hex_file);
    } else {
        fprintf(stderr, "Error: No program file specified\n");
        return 1;
    }

    // Run the simulation
    int rv = sim.run();

    // Dump memory contents to a file
    if(opt_args.count("dump_mem") > 0) {
        std::string dump_file = opt_args["dump_mem"].value.as_str;
        sim.dump_mem(dump_file);
    }

    return rv;
}
