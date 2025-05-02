#include "stdlib.h"
#include "vdev.h"

void exit(int status) {
    vdev_exit(status);
    __builtin_unreachable();  /* tell the compiler “this path won’t execute” */
}

////////////////////////////////////////////////////////////////////////////////
// Non standard functions

uint64_t instret() {
    uint32_t hi1, lo, hi2;
    do {
        hi1 = vdev_instreth();
        lo  = vdev_instret();
        hi2 = vdev_instreth();
    } while (hi1 != hi2);
    return ((uint64_t)hi1 << 32) | lo;
}

