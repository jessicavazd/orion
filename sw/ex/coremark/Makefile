SRCS := \
  core_list_join.c \
  core_main.c      \
  core_matrix.c    \
  core_state.c     \
  core_util.c      \
  barebones/core_portme.c

CFLAGS += -O2 \
          -I. -Ibarebones \
          -DITERATIONS=10 \
          -DHAS_FLOAT=0 \
          -DHAS_TIME_H=0 \
          -DHAS_STDIO=1 \
          -DHAS_PRINTF=1 \
          -DMULTITHREAD=1

FLAGS_STR:= $(CFLAGS)
CFLAGS += -DFLAGS_STR='"$(FLAGS_STR)"'
EXEC?=  coremark.elf

include ../common.mk