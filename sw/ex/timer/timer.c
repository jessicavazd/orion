#include <stdio.h>
#include "time.h"

//----------------------------------------------------------------------
// simple delay loop
//----------------------------------------------------------------------
// just burns some cycles so you see a non-zero delta
static void delay(void) {
    volatile uint32_t i;
    for (i = 0; i < 10000; i++) {
        // nothing
    }
}

int main(void) {
    
    puts("\n=== Timer Test ===\n");

    // read before/after
    uint64_t t0 = cycles();
    delay();
    uint64_t t1 = cycles();
    uint64_t delta = t1 - t0;

    printf("%lld  (start ticks)\n", t0);
    printf("%lld  (end ticks)\n", t1);
    printf("Elapsed ticks: %lld \n", delta);

    puts("=== Test Done ===\n");
    
    return 0;
}
