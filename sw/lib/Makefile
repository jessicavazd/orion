include ../../common.mk

# Override these variables 
BUILD_DIR?= build
SRCS?= 
LIBTINYC?= libtinyc.a

$(shell mkdir -p $(BUILD_DIR))
################################################################################
CFLAGS += -Wall -O0
CFLAGS += -march=rv32i -mabi=ilp32 -nostartfiles -ffreestanding
CFLAGS += -I$(ORION_HOME)/sw/lib/include

SRCS += start.S $(wildcard *.c)

OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS))
OBJS := $(patsubst %.S,$(BUILD_DIR)/%.o,$(OBJS))

default: build
################################################################################
# build: Builds the libtinyc library
################################################################################
.PHONY: build
build: $(BUILD_DIR)/$(LIBTINYC)

$(BUILD_DIR)/$(LIBTINYC): $(OBJS)
	@echo "Building $(LIBTINYC)"
	ar rcs $@ $^ 
	$(RISCV_TOOLCHAIN_PREFIX)objdump -htd $@ > $(basename $@).lst

$(BUILD_DIR)/%.o: %.c
	@echo "Compiling $<"
	$(RISCV_TOOLCHAIN_PREFIX)gcc $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S
	@echo "Compiling $<"
	$(RISCV_TOOLCHAIN_PREFIX)gcc $(CFLAGS) -c $< -o $@

################################################################################
# clean: Cleans the build directory
################################################################################
.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/*