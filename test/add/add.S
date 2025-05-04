.text
.globl main

#include "common.h"

main:
    # Zero addition
    TEST_RTYPE(0, add,  0,  0,  0)            # 0 + 0 = 0
    TEST_RTYPE(1, add, 10,  0, 10)            # x + 0 = x
    TEST_RTYPE(2, add,  0, 10, 10)            # 0 + y = y

    # Positive numbers
    TEST_RTYPE(3, add, 10, 20, 30)
    TEST_RTYPE(4, add, 12345, 67890, 80235)

    # Negative numbers
    TEST_RTYPE(5, add, -1, -1, -2)
    TEST_RTYPE(6, add, -10, -20, -30)
    TEST_RTYPE(7, add, -12345, -67890, -80235)

    # Mixed sign addition
    TEST_RTYPE(8, add, 10, -20, -10)
    TEST_RTYPE(9, add, -20, 10, -10)

    # Carry-over and boundary behavior
    TEST_RTYPE(10, add, 0x7FFFFFFF, 0x00000001, 0x80000000) # INT_MAX + 1 = INT_MIN (wrap)
    TEST_RTYPE(11, add, 0x7FFFFFFF, 0x7FFFFFFF, 0xFFFFFFFE) # INT_MAX + INT_MAX
    TEST_RTYPE(12, add, 0x80000000, 0x80000000, 0x00000000) # INT_MIN + INT_MIN = overflowed
    TEST_RTYPE(13, add, 0xFFFFFFFF, 1, 0x00000000)          # -1 + 1 = 0

    # Specific patterns
    TEST_RTYPE(14, add, 0xAAAAAAAA, 0x55555555, 0xFFFFFFFF)
    TEST_RTYPE(15, add, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE)

    # Sign extension edge cases
    TEST_RTYPE(16, add, -1, 0, -1)
    TEST_RTYPE(17, add, -1, -0x7FFFFFFF, 0x80000000)
    TEST_RTYPE(18, add, -1, -0x80000000, 0x7FFFFFFF)

    # Wrapping behavior
    TEST_RTYPE(19, add, 0x80000000, 0xFFFFFFFF, 0x7FFFFFFF) # INT_MIN + (-1) = INT_MAX
    TEST_RTYPE(20, add, 0x7FFFFFFE, 0x00000001, 0x7FFFFFFF)
    TEST_RTYPE(21, add, 0x7FFFFFFF, 0x00000001, 0x80000000)

################################################################################
TEST_FOOTER