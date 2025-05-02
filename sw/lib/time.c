#include "time.h"
#include <stdint.h>


extern volatile uint32_t _timer_addr_lo;
extern volatile uint32_t _timer_addr_hi;

static inline uint32_t timer_lo(void) {
    return *(volatile uint32_t*)&_timer_addr_lo;
}
static inline uint32_t timer_hi(void) {
    return *(volatile uint32_t*)&_timer_addr_hi;
}

clock_t cycles(void) {
    uint32_t hi1, lo, hi2;
    do {
        hi1 = timer_hi();
        lo  = timer_lo();
        hi2 = timer_hi();
    } while (hi1 != hi2);
    return ((uint64_t)hi1 << 32) | lo;
}