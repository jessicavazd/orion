# ***** Makefile to run Yosys synthesis *****
include ../../common.mk

BUILD_DIR?=build
$(shell mkdir -p $(BUILD_DIR))

LOG_FILE?=$(BUILD_DIR)/synth.log

FPGA_VENDOR?=xilinx
FPGA_FAMILY?=xc6s
FPGA_SYNTH_TCL_SCRIPT?=synth_fpga.tcl

# RTL_SRCS+= $(shell find $(RVATOM)/rtl -name "*.v")

default: fpga

.PHONY: fpga
fpga:
	@echo "Running Yosys synthesis for $(FPGA_VENDOR)::$(FPGA_FAMILY)"
	yosys -m slang -p 'tcl $(FPGA_SYNTH_TCL_SCRIPT) $(FPGA_VENDOR) $(FPGA_FAMILY) $(BUILD_DIR)' 2>&1 | tee $(LOG_FILE)


.PHONY: clean
clean:												#t# clean build dir
	$(call print_msg_root,Cleaning build files)
	rm -rf $(BUILD_DIR)