#pragma once

#ifndef EOF
    #define EOF (-1)
#endif

#ifndef NULL
    #define NULL ((void*)(0))
#endif

// Write a char to stdout
int putchar(char c);

// Write a string to stdout
int puts(const char *str);

// get a char from stdin
int getchar();

// get a string from stdin
char * gets(char *str);

/**
 * Supported Format specifiers for printf functions
 * - %d, %i, %u, %x, %b(optional), %o
 * - %p, %c, %s, %f(optional)
 * 
 * - fmt specifiers can be used with 'l', 'll', 'z' prefix to 
 *   parse the number as long, long long and size_t respectively.
 * - fmt specifiers can include padding
 */
int	printf(const char * fmt, ...) __attribute__((__format__ (__printf__, 1, 2)));


// ========== Non Standard Functions ==========
// Prints a char buffer in hexdump style
void dumphexbuf(char *buf, unsigned len, unsigned base_addr);