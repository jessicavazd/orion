include ../../../common.mk

# Override these variables 
BUILD_DIR?= build
SRCS?= 
EXEC?= a.elf
TRACE?= 
LOG?=

################################################################################
RVPREFIX := riscv64-unknown-elf
CFLAGS += -Wall -O0
CFLAGS += -march=rv32i -mabi=ilp32 -nostartfiles -ffreestanding
CFLAGS += -I$(ORION_HOME)/sw/lib/include
LFLAGS := -T $(ORION_HOME)/sw/lib/link/link.ld -Wl,-Map=$(BUILD_DIR)/$(basename $(EXEC)).map

SRCS += $(ORION_HOME)/sw/lib/start.S $(wildcard $(ORION_HOME)/sw/lib/*.c)

ORIONSIM_FLAGS:= 
ifeq ($(TRACE), 1)
    # Get the trace format from simulator
    ORIONSIM_TRACE_TYPE:= $(shell orionsim --help | grep -oP 'Trace type:\s*\K\w+' | tr '[:upper:]' '[:lower:]')
    ORIONSIM_FLAGS += -t --trace-file $(ORION_HOME)/trace.$(ORIONSIM_TRACE_TYPE)
endif

ifeq ($(LOG), 1)
    ORIONSIM_FLAGS += --log $(ORION_HOME)/sim.log
endif

SPIKE_FLAGS := --isa=rv32i -m0x10000:0x10000

default: build

################################################################################
# build: Builds the program
################################################################################
.PHONY: build
build: $(BUILD_DIR)/$(EXEC)

$(BUILD_DIR)/$(EXEC): $(SRCS)
	mkdir -p $(BUILD_DIR)
	$(RVPREFIX)-gcc $(CFLAGS) $^ -o $@ $(LFLAGS)
	$(RVPREFIX)-objdump -dt $@ > $(basename $@).lst
	$(RVPREFIX)-objcopy -O binary $@ $(basename $@).bin
	xxd -e -c 4 $(basename $@).bin | awk '{print $$2}' > $(basename $@).hex


################################################################################
# run: Runs the program on Orionsim
################################################################################
.PHONY: run
run: $(BUILD_DIR)/$(EXEC)
	@echo "Running $(EXEC)"
	orionsim $(ORIONSIM_FLAGS) $(basename $<).hex


################################################################################
# run-verif: Runs the program on both Spike and Orionsim, and compares the logs.
################################################################################
# SPIKE_LOG := $(BUILD_DIR)/spike.log
# ORIONSIM_LOG := $(BUILD_DIR)/orionsim.log
# DIFF_FILE := $(BUILD_DIR)/run.diff


.PHONY: run-verif
run-verif: $(BUILD_DIR)/$(EXEC)
	@echo "Running $(EXEC) on Spike and Orionsim"
	bash $(ORION_HOME)/scripts/spike_verif.sh --elf $(BUILD_DIR)/$(EXEC) --build-dir $(BUILD_DIR) \
		--spike-flags "$(SPIKE_FLAGS)" \
		--orionsim-flags "$(ORIONSIM_FLAGS)"


################################################################################
# clean: Cleans the build directory
################################################################################
.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/*