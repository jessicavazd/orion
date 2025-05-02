#include <vdev.h>
#include <mmio.h>

extern unsigned int __vdev_base_addr;

#define VDEV_ADDR               (uintptr_t)&__vdev_base_addr   // Base address of VDEV registers
#define VDEV_CONSOLE_ADDR       (VDEV_ADDR + 0x00)    // Console register
#define VDEV_CYCLE_ADDR         (VDEV_ADDR + 0x08)    // CYCLE register low-word
#define VDEV_CYCLE_ADDR_HI      (VDEV_ADDR + 0x0C)    // CYCLE register high-word
#define VDEV_INSTRET_ADDR       (VDEV_ADDR + 0x10)    // INSTRET register low-word
#define VDEV_INSTRET_ADDR_HI    (VDEV_ADDR + 0x14)    // INSTRET register high-word
#define VDEV_SIMCTRL_ADDR       (VDEV_ADDR + 0x1C)    // SIMCTRL register

void vdev_putchar(char c) {
    // set the console tx register
    uint32_t val = REG32(VDEV_CONSOLE_ADDR);
    val = (val & 0xFFFFFF00) | c;       // write char
    val = val | (1 << 16);              // set tx valid bit 
    REG32(VDEV_CONSOLE_ADDR) = val;
}

uint32_t vdev_cycles() {
    return REG32(VDEV_CYCLE_ADDR);
}

uint32_t vdev_cyclesh() {
    return REG32(VDEV_CYCLE_ADDR_HI);
}

uint32_t vdev_instret() {
    return REG32(VDEV_INSTRET_ADDR);
}

uint32_t vdev_instreth() {
    return REG32(VDEV_INSTRET_ADDR_HI);
}

void vdev_exit(int8_t retcode) {
    // set the exit code
    uint32_t val = REG32(VDEV_SIMCTRL_ADDR);
    val = (val & 0xFFFFFF00) | retcode; // write exit code
    val = val | (1 << 8);               // set finish request bit
    REG32(VDEV_SIMCTRL_ADDR) = val;
}
