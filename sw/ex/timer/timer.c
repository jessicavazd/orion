#include "console.h"
#include "time.h"


//----------------------------------------------------------------------
// hex printer for a 64-bit value
//----------------------------------------------------------------------
// prints exactly 16 hex digits, MSB first
// static void print_hex64(uint64_t x) {
//     for (int shift = 60; shift >= 0; shift -= 4) {
//         uint8_t nibble = (x >> shift) & 0xF;
//         char c = nibble < 10 ? ('0' + nibble)
//                              : ('A' + (nibble - 10));
//         console_putchar(c);
//     }
// }

//----------------------------------------------------------------------
// decimal printer for a 64-bit value
//----------------------------------------------------------------------
// prints the base-10 digits of x, MSB first
static void print_dec64(uint64_t x) {
    char buf[21];           // enough for max uint64_t + '\0'
    int  pos = 0;

    if (x == 0) {
        console_putchar('0');
        return;
    }

    // extract digits in reverse order
    while (x > 0) {
        buf[pos++] = '0' + (x % 10);
        x /= 10;
    }
    // now buf[0..pos-1] holds the digits in reverse

    // print them MSB first
    for (int i = pos - 1; i >= 0; i--) {
        console_putchar(buf[i]);
    }
}

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
    console_puts("\n=== Timer Test ===\n");

    // read before/after
    uint64_t t0 = cycles();
    print_dec64(t0);
    console_puts("  (start ticks)\n");

    delay();

    uint64_t t1 = cycles();
    print_dec64(t1);
    console_puts("  (end ticks)\n");

    // elapsed
    uint64_t delta = t1 - t0;
    console_puts("Elapsed ticks: ");
    print_dec64(delta);
    console_puts("\n");

    console_puts("=== Test Done ===\n");
    return 0;
}
