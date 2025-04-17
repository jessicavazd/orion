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

.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/*