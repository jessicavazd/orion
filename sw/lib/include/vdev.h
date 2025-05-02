#pragma once
#include <stdint.h>

// VDEV (Virtual Devices)

// Send a character to the console
void vdev_putchar(char c);

// Get the current cycle count
uint32_t vdev_cycles();

// Get the current cycle count high word
uint32_t vdev_cyclesh();

// Get the number of instructions retired
uint32_t vdev_instret();

// Get the number of instructions retired high word
uint32_t vdev_instreth();

// Exit the simulation with a return code
void vdev_exit(int8_t retcode);

