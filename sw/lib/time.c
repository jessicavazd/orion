#include "vdev.h"
#include "time.h"


clock_t cycles() {
    uint32_t hi1, lo, hi2;
    do {
        hi1 = vdev_cyclesh();
        lo  = vdev_cycles();
        hi2 = vdev_cyclesh();
    } while (hi1 != hi2);
    return ((uint64_t)hi1 << 32) | lo;
}