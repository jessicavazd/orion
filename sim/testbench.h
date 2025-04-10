#pragma once

#include <stdint.h>
#include <map>

#ifdef TRACE_FST
#include <verilated_fst_c.h>
#else
#include <verilated_vcd_c.h>
#endif

/*
    A generic testbench class that instantiates the dut, and provides
    methods to control and trace the simulation.
    - It supports both fst and vcd traces.
    - FST is recommended (but not default) as it is more compact and faster.
    - The testbench can be used with any top-level module.
*/
template <class VTop>
class Testbench {
public:
    // DUT
    VTop* dut_ = nullptr;

    //== Setup =============================
    // Construct a testbench object
    Testbench();

    // Destruct the testbench object
    virtual ~Testbench();

    // Register clock and reset signals
    void register_clk(bool *clksign) { sig_clk_ = clksign; }
    void register_rst(bool *rstsign) { sig_rst_ = rstsign; }

    //== Simulation control ================
    // Check if simulation finished
    bool finished();

    // Reset system
    void reset(int ncycles = 2);

    // Tick one cucle
    void tick();

    //== Trace functions ===================
    // Check if trace is open
    inline virtual bool is_trace_open() { return trace_ != nullptr; }

    // Open a VCD/Fst trace
    virtual void open_trace(std::string trace_file);

    // Close a trace
    virtual void close_trace();

    //===== Query simulation =====
    // get the number of cycles elapsed till now
    virtual uint64_t get_cycles() {return cycles_;}

private:
    // Trace file ptr
#ifdef TRACE_FST
    VerilatedFstC * trace_ = nullptr;
#else
    VerilatedVcdC * trace_ = nullptr;
#endif

    // Track number of clock cyles
    uint64_t cycles_ = 0l;
    
    // Signals
    bool* sig_clk_ = nullptr;
    bool* sig_rst_ = nullptr;
};


template <class VTop>
Testbench<VTop>::Testbench() {
    dut_ = new VTop;
    Verilated::traceEverOn(true);
    cycles_ = 0L;
}

template <class VTop>
Testbench<VTop>::~Testbench() {
    if(is_trace_open())
        close_trace();
    delete trace_;
    delete dut_;
}

template <class VTop>
bool Testbench<VTop>::finished() {
    return Verilated::gotFinish();
}

template <class VTop>
void Testbench<VTop>::reset(int ncycles) {
    cycles_ = 0;
    *sig_rst_ = 1;
    for(int i = 0; i < ncycles; i++) {
        tick();
    }
    *sig_rst_ = 0;
}

template <class VTop>
void Testbench<VTop>::tick() {
    // Increment our own internal time reference
    cycles_++;

    // Make sure any combinatorial logic depending upon
    // inputs that may have changed before we called tick()
    // has settled before the rising edge of the clock.
    *sig_clk_ = 0;
    dut_->eval();

    //  Dump values to our trace file before clock edge
    if(is_trace_open()) {
        trace_->dump(10*cycles_-2);
    }

    // ---------- Toggle the clock ------------

    // Rising edge
    *sig_clk_ = 1;
    dut_->eval();

    //  Dump values to our trace file after clock edge
    if(is_trace_open()) 
        trace_->dump(10*cycles_);

    // Falling edge
    *sig_clk_ = 0;
    dut_->eval();

    if (trace_) {
        // This portion, though, is a touch different.
        // After dumping our values as they exist on the
        // negative clock edge ...
        trace_->dump(10*cycles_+5);
        //
        // We'll also need to make sure we flush any I/O to
        // the trace file, so that we can use the assert()
        // function between now and the next tick if we want to.

#ifndef TRACE_FST
        // Flushing each cycle in fst mode is too slow.
        trace_->flush();
#endif
    }
}

template <class VTop>
void Testbench<VTop>::open_trace(std::string trace_file) {
    if(!is_trace_open()) {
#ifdef TRACE_FST
        trace_ = new VerilatedFstC;
#else
        trace_ = new VerilatedVcdC;
#endif
        dut_->trace(trace_, 99);
        trace_->open(trace_file.c_str());
    }
}

template <class VTop>
void Testbench<VTop>::close_trace() {
    if (is_trace_open()) {
        trace_->close();
    }
}

