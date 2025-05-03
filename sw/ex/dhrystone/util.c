#include <platform.h>

#ifndef HEAP_SIZE
#define HEAP_SIZE 2048
#endif

char heap_memory[HEAP_SIZE];
int heap_memory_used = 0;

char *malloc(int size) {
    char *p = heap_memory + heap_memory_used;
    // printf("[malloc(%d) -> %d (%d..%d)]", size, (int)p, heap_memory_used, heap_memory_used + size);
    heap_memory_used += size;
    if (heap_memory_used > 1024){
        printf("malloc: out of memory\n");
        exit(1);
    }
    return p;
}


char* strcpy(char* dest, const char* src) {
    char* ret = dest;
    while ((*dest++ = *src++) != '\0');
    return ret;
}

long time() {
#ifdef NO_GET_CYCLES
    return 0;
#else
    return cycles() / CLK_FREQ;
#endif
}