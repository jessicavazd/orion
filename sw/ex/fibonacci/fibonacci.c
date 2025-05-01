#include "console.h"

// Print a non-negative integer using console_putchar
static void print_num(int n) {
    if (n == 0) {
        console_putchar('0');
        return;
    }
    char buf[12];
    int i = 0;
    while (n > 0) {
        buf[i++] = '0' + (n % 10);
        n /= 10;
    }
    // digits are in reverse
    while (i--) {
        console_putchar(buf[i]);
    }
}

// Simple recursive Fibonacci
static int fib_recursive(int n) {
    if (n < 2) return n;
    return fib_recursive(n-1) + fib_recursive(n-2);
}

// Iterative Fibonacci
static int fib_iterative(int n) {
    if (n < 2) return n;
    int a = 0, b = 1;
    for (int i = 2; i <= n; i++) {
        int next = a + b;
        a = b;
        b = next;
    }
    return b;
}

int main(void) {
    console_puts("Fibonacci Comparison Demo:");
    const int length = 20;

    for (int i = 0; i < length; i++) {
        int fi = fib_iterative(i);
        int fr = fib_recursive(i);

        // print index
        print_num(i);
        console_puts(": iterative = ");
        print_num(fi);
        console_puts(", recursive = ");
        print_num(fr);

        // comparison
        if (fi == fr) {
            console_puts("  [OK]");
        } else {
            console_puts("  [ERROR]");
        }

        console_putchar('\n');
    }

    return 0;
}
