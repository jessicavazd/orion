#include "console.h"

extern volatile int _console_addr;

void console_putchar(char c) {
    // Write the character to the console
    _console_addr = c;
}

void console_puts(const char *str) {
    while (*str) {
        console_putchar(*str++);
    }
}