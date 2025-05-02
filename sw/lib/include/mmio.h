#pragma once
#include <stdint.h>

// Memory-Mapped Reg Access Macros
#define REG8(addr)  *((volatile uint8_t*)   (addr))
#define REG16(addr) *((volatile uint16_t*)  (addr))
#define REG32(addr) *((volatile uint32_t*)  (addr))
#define REG64(addr) *((volatile uint64_t*)  (addr))
