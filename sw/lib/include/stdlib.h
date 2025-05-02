#pragma once
#include <stdint.h>

// Define Exit codes
#define EXIT_FAILURE 1
#define EXIT_SUCCESS 0

void exit(int status) __attribute__((noreturn));


// Non standard functions
uint64_t instret();