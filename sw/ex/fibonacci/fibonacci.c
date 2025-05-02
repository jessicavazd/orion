#include <stdio.h>

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
    puts("Fibonacci Comparison Demo:\n");
    const int length = 20;

    for (int i = 0; i < length; i++) {
        int fi = fib_iterative(i);
        int fr = fib_recursive(i);

        // print index
        printf("%d : iterative = %d, recursive = %d",i, fi, fr);

        // comparison
        if (fi == fr) {
            puts("  [OK]");
        } else {
            puts("  [ERROR]");
        }
        putchar('\n');
    }

    return 0;
}
