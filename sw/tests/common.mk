CLR_RD := \033[0;31m
CLR_GR := \033[0;32m
CLR_CY := \033[0;36m
CLR_BL := \033[34m
CLR_NC := \033[0m

ifeq ($(ORION_HOME), )
    $(error "ORION_HOME environment variable not set, did you source the sourceme script?")
endif

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
LFLAGS := -T $(ORION_HOME)/sw/lib/link.ld -Wl,-Map=$(BUILD_DIR)/$(basename $(EXEC)).map


ORIONSIM_FLAGS:= 
ifeq ($(TRACE), 1)
    # Get the trace format from simulator
    ORIONSIM_TRACE_TYPE:= $(shell orionsim --help | grep -oP 'Trace type:\s*\K\w+' | tr '[:upper:]' '[:lower:]')
    ORIONSIM_FLAGS += -t --trace-file $(ORION_HOME)/trace.$(ORIONSIM_TRACE_TYPE)
endif

ifeq ($(LOG), 1)
    ORIONSIM_FLAGS += --log $(ORION_HOME)/sim.log
endif

all: build

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
SPIKE_LOG := $(BUILD_DIR)/spike.log
ORIONSIM_LOG := $(BUILD_DIR)/orionsim.log
DIFF_FILE := $(BUILD_DIR)/run.diff

.PHONY: run-verif
run-verif: $(BUILD_DIR)/$(EXEC)
	@echo "Running $(EXEC) on Spike and Orionsim"
	spike --isa=rv32i -m0x10000:0x10000 --log-commits $(BUILD_DIR)/$(EXEC) 2>&1 | tail -n +6 > $(SPIKE_LOG)
	orionsim $(ORIONSIM_FLAGS) --log $(ORIONSIM_LOG) --log-format spike $(basename $<).hex || true
	@diff -y --width=140 $(SPIKE_LOG) $(ORIONSIM_LOG) | expand -t 8 > $(DIFF_FILE)
	@grep -qE '\||<|>' $(DIFF_FILE) && \
		printf "$(CLR_RD)[!] Verification failed: Differences found$(CLR_NC)\n" && exit 1 || \
		printf "$(CLR_GR)[+] Verification success: No differences found in logs$(CLR_NC)\n"


################################################################################
# clean: Cleans the build directory
################################################################################
.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/*