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
LFLAGS := -T $(ORION_HOME)/sw/lib/link.ld 

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

.PHONY: build
build: $(BUILD_DIR)/$(EXEC)

$(BUILD_DIR)/$(EXEC): $(SRCS)
	mkdir -p $(BUILD_DIR)
	$(RVPREFIX)-gcc $(CFLAGS) $^ -o $@ $(LFLAGS)
	$(RVPREFIX)-objdump -dt $@ > $(basename $@).lst
	$(RVPREFIX)-objcopy -O binary $@ $(basename $@).bin
	xxd -e -c 4 $(basename $@).bin | awk '{print $$2}' > $(basename $@).hex

.PHONY: run
run: $(BUILD_DIR)/$(EXEC)
	@echo "Running $(EXEC)"
	orionsim $(ORIONSIM_FLAGS) $(basename $<).hex


.PHONY: run-verify
run-verify: $(BUILD_DIR)/$(EXEC)
	@echo "Running $(EXEC) with spike verification"
	spike --isa=rv32i -m0x10000:0x10000 --log-commits $(BUILD_DIR)/$(EXEC) |& tail -n +6 > $(BUILD_DIR)/spike.log
	orionsim $(ORIONSIM_FLAGS) --log $(BUILD_DIR)/orionsim.log --log-format spike $(basename $<).hex
	@echo "Comparing logs"
	diff -y -W 260 $(BUILD_DIR)/spike.log $(BUILD_DIR)/orionsim.log > run_diff && echo -e "$(CLR_GR)[+] Verification Success$(CLR_NC)" || \
	{ echo -e "$(CLR_RD)[!] Verification failed$(CLR_NC)"; exit 1; }
# diff --side-by-side $(BUILD_DIR)/spike.log $(BUILD_DIR)/orionsim.log | awk '{ printf "%-80.80s %-80.80s\n", substr($0,1,80), substr($0,82) }'


# $(ORION_HOME)/scripts/spike-log-diff.py $(BUILD_DIR)/spike.log $(BUILD_DIR)/orionsim.log


.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/*