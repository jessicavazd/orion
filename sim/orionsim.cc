#include <iostream>
#include <string>
#include <vector>
#include <fstream>

#include "argparse.h"
#include "testbench.h"

#include "Vorion_soc_headers.h"

#define MEM_ADDR 0x0000000
#define MEM_SIZE (32*1024)

#define RV_EBREAK 0x00100073

#define SIMLOG(x, ...) printf("[+] " x, ##__VA_ARGS__)

#ifdef TRACE_FST
    #define TRACE_FILE "trace.fst"
#else
    #define TRACE_FILE "trace.vcd"
#endif

std::string banner = 
"==========================\n"
" OrionSim \n"
"==========================\n";

class OrionSim {
public:
    OrionSim() {
        // Initialize the simulator
        printf("%s", banner.c_str());
        
        SIMLOG("Initializing simulator\n");
     
        tb = new Testbench<Vorion_soc>();
        tb->register_clk((bool*)&tb->dut_->clk_i);
        tb->register_rst((bool*)&tb->dut_->rst_i);

        signal_ptrs.instr_valid = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_valid;
        signal_ptrs.instr = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_instr;
        signal_ptrs.pc = (uint32_t*)&tb->dut_->orion_soc->core->writeback_stg->dbg_pc;
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

    int run() {
        // Run the simulation
        SIMLOG("Starting simulation\n");
        int rv = 0;

        SIMLOG("Resetting SoC\n");
        tb->reset();

        // Tick the simulation
        uint32_t finish_pc = 0;
        bool finish_req = false;
        while(!tb->finished() && tb->get_cycles() < max_cycles && !finish_req) {
            if(tb->get_cycles() % 10000 == 0) {
                SIMLOG("  - %lu cycles\n", tb->get_cycles());
            }

            // Check for EBREAK instruction
            finish_req = got_finish(&finish_pc);

            tb->tick();

            if(log_f) {
                sim_log();
            }
        }

        SIMLOG("Simulation finished @ %lu cycles\n", tb->get_cycles());

        if(tb->get_cycles() >= max_cycles) {
            SIMLOG("  Reached maximum cycles: %lu)\n", max_cycles);
            rv = 0;
        } else if(tb->finished()) {
            SIMLOG("  $finish called from RTL\n");
            rv = 1;
        } else if (finish_req) {
            SIMLOG("  EBreak hit at PC: 0x%08x\n", finish_pc);
            rv = 0;
        }
        else {
            SIMLOG("  Unknown reason\n");
            rv = -1;
        }
        return rv;
    }

    bool got_finish(uint32_t *ebreak_pc) {
        if (*signal_ptrs.instr_valid && *signal_ptrs.instr == RV_EBREAK) {
            *ebreak_pc = *signal_ptrs.pc;    // save the PC of the EBREAK instruction
            return true;
        }
        return false;
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
        uint32_t addr = 0x0000000;
        uint64_t nbytes_written = 0;

        while(std::getline(hex_file, line)) {
            if(line.empty()) continue;
            
            // Update address if line starts with '@'
            if(line[0] == '@') {
                addr = std::stoul(line.substr(1, line.size() - 1), nullptr, 16);
                continue;
            }

            // Parse the data line
            uint32_t data = std::stoul(line, nullptr, 16);
            
            // Check if the address is within the valid range
            if(!(/*addr >= MEM_ADDR || */ addr < MEM_ADDR + MEM_SIZE)) {
                fprintf(stderr, "Error: Address out of range: 0x%08X\n", addr);
                continue;
            }
            
            // Write the data word to the memory
            uint32_t word_index = (addr - MEM_ADDR) / 4;
            tb->dut_->orion_soc->imem->mem[word_index] = data;
            addr += 4;
            nbytes_written += 4;
        }

        hex_file.close();
        SIMLOG("Loaded %lu bytes in imem\n", nbytes_written);
    }

    void dump_mem(std::string filename, uint32_t addr, uint32_t size) {
        SIMLOG("Dumping memory to file: %s\n", filename.c_str());
        // TODO: 
    }

    void set_max_cycles(uint64_t cycles) {
        // Set the maximum number of cycles
        SIMLOG("Setting maximum cycles to: %lu\n", cycles);
        max_cycles = cycles;
    }

    void sim_log() {
        uint32_t pc = tb->dut_->orion_soc->core->fetch_stg->pc;
        uint32_t instr = tb->dut_->orion_soc->core->decode_stg->instr;
        fprintf(log_f, "[%lu] PC: 0x%08x, Instr: 0x%08x\n", tb->get_cycles(), pc, instr);
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


private:
    Testbench<Vorion_soc> *tb;
    uint64_t max_cycles = 100000;

    struct {
        uint32_t *instr_valid;
        uint32_t *instr;
        uint32_t *pc;        
    } signal_ptrs;

    FILE *log_f = nullptr;
};



int main(int argc, char** argv) {
    // Parse Arguments
    ArgParse::ArgumentParser parser("orionsim", "RTL simulator for the OrionSoC");
    parser.add_argument({"-m", "--max-cycles"}, "Maximum number of cycles to simulate", ArgParse::ArgType_t::INT);
    parser.add_argument({"-t", "--trace"}, "Enable trace", ArgParse::ArgType_t::BOOL, "false");
    parser.add_argument({"--trace-file"}, "Specify a trace file", ArgParse::ArgType_t::STR, TRACE_FILE);
    parser.add_argument({"-l", "--log"}, "Enable simulation log", ArgParse::ArgType_t::STR);

    if(parser.parse_args(argc, argv) != 0) {
        return 1;
    }
    auto opt_args = parser.get_opt_args();
    auto pos_args = parser.get_pos_args();

    // Create the simulator instance
    OrionSim sim;

    // Open trace file
    if(opt_args["trace"].value.as_bool) {
        std::string trace_file = opt_args["trace_file"].value.as_str;
        sim.open_trace(trace_file);
    }

    if(opt_args.count("log") > 0) {
        std::string log_file = opt_args["log"].value.as_str;
        sim.open_log(log_file);
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

    return rv;
}
