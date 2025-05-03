SRCS := dhry_1.c dhry_2.c util.c

CFLAGS += -std=gnu89 -O2 -I. -DRISCV -DTIME -DDHRY_ITERS=40000

# NOTE: the following flag disables timing functions and allows for proper verification
# with spike using `make run-verif`. Uncomment when needed.
CFLAGS += -DNO_GET_CYCLES

ORIONSIM_FLAGS+= --max-cycles 1000000000
EXEC?=  dhrystone.elf

include ../common.mk