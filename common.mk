################################################################################
# Common Makefile configurations
################################################################################

# Define bash color codes
ifndef NO_COLOR
CLR_RD:=\033[0;31m
CLR_GR:=\033[0;32m
CLR_YL:=\033[0;33m
CLR_CY:=\033[0;36m
CLR_BL:=\033[34m
CLR_MG:=\033[35m
CLR_B :=\033[1m
CLR_NB:=\033[22m
CLR_D :=\033[2m
CLR_ND:=\033[22m
CLR_NC:=\033[0m
endif

# Set the default target to 'default'
.DEFAULT_GOAL := all

# This disables printing the directory name when invoking make in subdirectories
MAKEFLAGS += --no-print-directory

# Check if ORION_HOME is set
ifeq ($(ORION_HOME), )
    $(error "ORION_HOME environment variable not set, did you source the sourceme script?")
endif

# Define the riscv toolchain prefix
RISCV_TOOLCHAIN_PREFIX?= riscv64-unknown-elf-
