.section .text
.global main
.option norvc           # force plain 32-bit instructions

#include "common.h"

main:
    ############################################################################
    # MUL (signed multiplication)

    # Small values
    TEST_RTYPE(1, mul,  5, -3, -15)
    TEST_RTYPE(2, mul, -5,  3, -15)
    TEST_RTYPE(3, mul, -5, -3,  15)
    TEST_RTYPE(4, mul, -5,  0,   0)
    TEST_RTYPE(5, mul,  0,  5,   0)
    TEST_RTYPE(6, mul,  0, -5,   0)
    TEST_RTYPE(7, mul,  0,  0,   0)

    # Large values
    TEST_RTYPE(8,  mul, 0x7FFFFFFF, 0x7FFFFFFF, 1)
    TEST_RTYPE(9,  mul, 0x7FFFFFFF, 0xFFFFFFFF, 0x80000001)
    TEST_RTYPE(10, mul, 0xFFFFFFFF, 0x7FFFFFFF, 0x80000001)
    TEST_RTYPE(11, mul, 0xFFFFFFFF, 0xFFFFFFFF, 1)
    TEST_RTYPE(12, mul, 0x80000000, 0x80000000, 0)
    TEST_RTYPE(13, mul, 0x80000000, 0x7FFFFFFF, 0x80000000)
    TEST_RTYPE(14, mul, 0x80000000, -1,         0x80000000)
    TEST_RTYPE(15, mul, 0x7FFFFFFE, 2,          0xFFFFFFFC)
    TEST_RTYPE(16, mul, 0x80000000, 2,          0x00000000)
    TEST_RTYPE(17, mul, 0xFFFF0000, 0xFFFF0000, 0x00000000)

    ############################################################################
    # MULH
    # Small values
    TEST_RTYPE(18,  mulh,  5,  3,  0)
    TEST_RTYPE(19,  mulh,  5, -3, -1)
    TEST_RTYPE(20,  mulh, -5,  3, -1)
    TEST_RTYPE(21,  mulh, -5, -3,  0)
    TEST_RTYPE(22,  mulh, -5,  0,  0)
    TEST_RTYPE(23,  mulh,  0,  5,  0)
    TEST_RTYPE(24,  mulh,  0, -5,  0)
    TEST_RTYPE(25,  mulh,  0,  0,  0)

    # Large values
    TEST_RTYPE(26, mulh, 0x7FFFFFFF, 0x7FFFFFFF, 0x3FFFFFFF)
    TEST_RTYPE(27, mulh, 0x7FFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF)
    TEST_RTYPE(28, mulh, 0xFFFFFFFF, 0x7FFFFFFF, 0xFFFFFFFF)
    TEST_RTYPE(29, mulh, 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000)
    TEST_RTYPE(30, mulh, 0x80000000, 0x80000000, 0x40000000)
    TEST_RTYPE(31, mulh, 0x80000000, 0x7FFFFFFF, 0xC0000000)
    TEST_RTYPE(32, mulh, 0x80000000, -1,         0x00000000)
    TEST_RTYPE(33, mulh, 0x7FFFFFFE, 2,          0x00000000)
    TEST_RTYPE(34, mulh, 0x80000000, 2,          0xFFFFFFFF)
    TEST_RTYPE(35, mulh, 0xFFFF0000, 0xFFFF0000, 0x00000001)

    ############################################################################
    # MULHSU
    
    # Small values
    TEST_RTYPE(40, mulhsu,  5,    3,    0)
    TEST_RTYPE(41, mulhsu,  5,   -3,    4)
    TEST_RTYPE(42, mulhsu, -5,    3,   -1)
    TEST_RTYPE(43, mulhsu, -5,   -3,   -5)
    TEST_RTYPE(44, mulhsu, -5,    0,    0)
    TEST_RTYPE(45, mulhsu,  0,    5,    0)
    TEST_RTYPE(46, mulhsu,  0,   -5,    0)
    TEST_RTYPE(47, mulhsu,  0,    0,    0)

    # Large values
    TEST_RTYPE(48, mulhsu,  0x7FFFFFFF, 0x7FFFFFFF, 0x3FFFFFFF)
    TEST_RTYPE(49, mulhsu,  0x7FFFFFFF, 0xFFFFFFFF, 0x7FFFFFFE)
    TEST_RTYPE(50, mulhsu,  0xFFFFFFFF, 0x7FFFFFFF, 0xFFFFFFFF)
    TEST_RTYPE(51, mulhsu,  0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF)
    TEST_RTYPE(52, mulhsu,  0x80000000, 0x80000000, 0xC0000000)
    TEST_RTYPE(53, mulhsu,  0x80000000, 0x7FFFFFFF, 0xC0000000)
    TEST_RTYPE(54, mulhsu,  0x80000000, -1,         0x80000000)
    TEST_RTYPE(55, mulhsu,  0x7FFFFFFE, 2,          0x00000000)
    TEST_RTYPE(56, mulhsu,  0x80000000, 2,          0xFFFFFFFF)
    TEST_RTYPE(57, mulhsu,  0xFFFF0000, 0xFFFF0000, 0xFFFF0001)


    ############################################################################
    # MULHU
    # Small values
    TEST_RTYPE(60, mulhu,  5,    3,    0x00000000)
    TEST_RTYPE(61, mulhu,  5,   -3,    0x00000004)
    TEST_RTYPE(62, mulhu, -5,    3,    0x00000002)
    TEST_RTYPE(63, mulhu, -5,   -3,    0xFFFFFFF8)
    TEST_RTYPE(64, mulhu, -5,    0,    0x00000000)
    TEST_RTYPE(65, mulhu,  0,    5,    0x00000000)
    TEST_RTYPE(66, mulhu,  0,   -5,    0x00000000)
    TEST_RTYPE(67, mulhu,  0,    0,    0x00000000)

    # Large values
    TEST_RTYPE(68, mulhu,  0x7FFFFFFF, 0x7FFFFFFF, 0x3FFFFFFF)
    TEST_RTYPE(69, mulhu,  0x7FFFFFFF, 0xFFFFFFFF, 0x7FFFFFFE)
    TEST_RTYPE(70, mulhu,  0xFFFFFFFF, 0x7FFFFFFF, 0x7FFFFFFE)
    TEST_RTYPE(71, mulhu,  0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE)
    TEST_RTYPE(72, mulhu,  0x80000000, 0x80000000, 0x40000000)
    TEST_RTYPE(73, mulhu,  0x80000000, 0x7FFFFFFF, 0x3FFFFFFF)
    TEST_RTYPE(74, mulhu,  0x80000000, -1,         0x7FFFFFFF)
    TEST_RTYPE(75, mulhu,  0x7FFFFFFE, 2,          0x00000000)
    TEST_RTYPE(76, mulhu,  0x80000000, 2,          0x00000001)
    TEST_RTYPE(77, mulhu,  0xFFFF0000, 0xFFFF0000, 0xFFFE0001)

    
    ############################################################################
    # DIV
    # Divide by ±1
    TEST_RTYPE(80, div, 0x7FFFFFFF,  1,           0x7FFFFFFF)  #  INT_MAX /  1 =  INT_MAX
    TEST_RTYPE(81, div, 0x80000000,  1,           0x80000000)  #  INT_MIN /  1 =  INT_MIN
    TEST_RTYPE(82, div, 0x7FFFFFFF, -1,           0x80000001)  #  INT_MAX / -1 = -INT_MAX

    # Numerator smaller than divisor → 0
    TEST_RTYPE(83, div, 5,           7,           0)            #   5 /   7 =  0
    TEST_RTYPE(84, div, 5,          -7,           0)            #   5 /  -7 =  0
    TEST_RTYPE(85, div, -5,          7,           0)            #  -5 /   7 =  0
    TEST_RTYPE(86, div, -5,         -7,           0)            #  -5 /  -7 =  0

    # Divisor = INT_MIN (–2^31)
    TEST_RTYPE(87, div, 0x7FFFFFFF,  0x80000000, 0)            #  INT_MAX / INT_MIN = 0
    TEST_RTYPE(88, div, 0x80000000,  0x80000000, 1)            #  INT_MIN / INT_MIN = 1

    # Overflow-adjacent cases: INT_MIN ÷ ±2
    TEST_RTYPE(89, div, 0x80000000,  2,           0xC0000000) # -2^31 /  2 = -2^30
    TEST_RTYPE(90, div, 0x80000000, -2,           0x40000000) # -2^31 / -2 =  2^30

    # Divide-by-zero at the extremes
    TEST_RTYPE(91, div, 0x7FFFFFFF,  0,           0xFFFFFFFF) #  INT_MAX / 0 = -1
    TEST_RTYPE(92, div, 0x80000000,  0,           0xFFFFFFFF) #  INT_MIN / 0 = -1

    TEST_RTYPE(93, div, -5, 2, -2)
    TEST_RTYPE(94, div, -5, -2, 2)
    TEST_RTYPE(95, div, 5, 0, -1)
    TEST_RTYPE(96, div, -5, 0, -1)
    TEST_RTYPE(97, div, 0, 5, 0)
    TEST_RTYPE(98, div, 0, -5, 0)
    TEST_RTYPE(99, div, 0, 0, -1)
    TEST_RTYPE(100, div, 5, 2, 2)
    TEST_RTYPE(101, div, 5, -2, -2)
    TEST_RTYPE(102, div, 0x7FFFFFFF, 0x7FFFFFFF, 1)
    TEST_RTYPE(103, div, 1234, 0, 0xFFFFFFFF)
    TEST_RTYPE(104, div, 0x80000000, -1, 0x80000000) // INT_MIN / -1 = INT_MIN


    # TEST_RTYPE(103, rem, 1234, 0, 1234)
    # TEST_RTYPE(104, remu, 1234, 0, 1234)
    # TEST_RTYPE(106, rem, 0x80000000, -1, 0x0) // INT_MIN % -1 = 0

    ############################################################################
    # DIVU
    
    # Divide by 1 → result = numerator
    TEST_RTYPE(105, divu, 0xFFFFFFFF, 1,          0xFFFFFFFF)  # max / 1 = max
    TEST_RTYPE(106, divu, 0x00001234, 1,          0x00001234)  #  0x1234 / 1 = 0x1234

    # Numerator < divisor → 0
    TEST_RTYPE(107, divu, 5,           7,          0x00000000)  # 5 / 7 = 0
    TEST_RTYPE(108, divu, 5,   0xFFFFFFFE,         0x00000000)  # 5 / (max–1) = 0

    # Divisor = max → numerator<max→0; numerator=max→1
    TEST_RTYPE(109, divu, 0x7FFFFFFF, 0xFFFFFFFF, 0x00000000)  # mid / max = 0
    TEST_RTYPE(110, divu, 0xFFFFFFFF, 0xFFFFFFFF, 0x00000001)  # max / max = 1

    # “Typical” divides of large values
    TEST_RTYPE(111, divu, 0xFFFFFFFF, 2,          0x7FFFFFFF)  # max / 2 = 0x7FFFFFFF
    TEST_RTYPE(112, divu, 0x80000000, 2,          0x40000000)  # 2^31 / 2 = 2^30
    TEST_RTYPE(113, divu, 0x80000001, 2,          0x40000000)  # (2^31+1)/2 = 2^30

    # Zero numerator (non‐zero divisor) → 0
    TEST_RTYPE(114, divu, 0x00000000, 5,          0x00000000)  # 0 / 5 = 0
    TEST_RTYPE(115, divu, 0x00000000, 0xFFFFFFFF, 0x00000000)  # 0 / max = 0

    # Divide by zero → result = max
    TEST_RTYPE(116, divu, 5,           0,          0xFFFFFFFF)  # 5 / 0 = max
    TEST_RTYPE(117, divu, 0x00000000,  0,          0xFFFFFFFF)  # 0 / 0 = max

    ############################################################################
    # REM

    # REM (signed remainder) corner‐case tests

    # Remainder by ±1 → always 0
    TEST_RTYPE(118, rem,  0x7FFFFFFF,  1,           0)            #  INT_MAX  %  1 =  0
    TEST_RTYPE(119, rem,  0x80000000,  1,           0)            #  INT_MIN  %  1 =  0
    TEST_RTYPE(120, rem,  0x7FFFFFFF, -1,           0)            #  INT_MAX  % -1 =  0
    TEST_RTYPE(121, rem,  0x80000000, -1,           0)            #  INT_MIN  % -1 =  0 (overflow case)

    # Numerator smaller than |divisor| → remainder = numerator
    TEST_RTYPE(122, rem,  5,           7,           5)            #   5 %   7 =  5
    TEST_RTYPE(123, rem,  5,          -7,           5)            #   5 %  -7 =  5
    TEST_RTYPE(124, rem, -5,           7,          -5)            #  -5 %   7 = -5
    TEST_RTYPE(125, rem, -5,          -7,          -5)            #  -5 %  -7 = -5

    # Divisor = INT_MIN (–2^31)
    TEST_RTYPE(126, rem,  0x7FFFFFFF,  0x80000000, 0x7FFFFFFF)     #  INT_MAX % INT_MIN = INT_MAX
    TEST_RTYPE(127, rem,  0x80000000,  0x80000000, 0)             #  INT_MIN % INT_MIN = 0

    # Typical mixed‐sign cases
    TEST_RTYPE(128, rem,  7,           3,           1)            #   7 %   3 =  1
    TEST_RTYPE(129, rem,  7,          -3,           1)            #   7 %  -3 =  1
    TEST_RTYPE(130, rem, -7,           3,          -1)            #  -7 %   3 = -1
    TEST_RTYPE(131, rem, -7,          -3,          -1)            #  -7 %  -3 = -1

    # Exact divisibility → remainder = 0
    TEST_RTYPE(132, rem,  6,           3,           0)            #   6 %   3 =  0
    TEST_RTYPE(133, rem,  6,          -3,           0)            #   6 %  -3 =  0
    TEST_RTYPE(134, rem, -6,           3,           0)            #  -6 %   3 =  0
    TEST_RTYPE(135, rem, -6,          -3,           0)            #  -6 %  -3 =  0

    # Divide‐by‐zero → remainder = dividend
    TEST_RTYPE(136, rem,  5,           0,           5)            #   5 %   0 =  5
    TEST_RTYPE(137, rem, -5,           0,          -5)            #  -5 %   0 = -5
    TEST_RTYPE(138, rem,  0,           0,           0)            #   0 %   0 =  0
    TEST_RTYPE(139, rem,  0x7FFFFFFF,  0,    0x7FFFFFFF)         #  INT_MAX %  0 = INT_MAX
    TEST_RTYPE(140, rem,  0x80000000,  0,    0x80000000)         #  INT_MIN %  0 = INT_MIN


    ############################################################################
    # REMU

    # REMU (unsigned remainder) corner‐case tests

    # Remainder by 1 → always 0
    TEST_RTYPE(141, remu, 0x00000000, 1,          0x00000000)  # 0     % 1 = 0
    TEST_RTYPE(142, remu, 0x00001234, 1,          0x00000000)  # 0x1234 % 1 = 0
    TEST_RTYPE(143, remu, 0xFFFFFFFF, 1,          0x00000000)  # max   % 1 = 0

    # Numerator < divisor → remainder = numerator
    TEST_RTYPE(144, remu, 5,           7,          5)           #   5 %   7 = 5
    TEST_RTYPE(145, remu, 5,    0xFFFFFFFE,        5)           #   5 % (max-1) = 5
    TEST_RTYPE(146, remu, 0x7FFFFFFF, 0xFFFFFFFF, 0x7FFFFFFF) # mid % max = mid

    # Divisor = max → numerator<max→numerator; numerator=max→0
    TEST_RTYPE(147, remu, 0x7FFFFFFF, 0xFFFFFFFF, 0x7FFFFFFF) # mid % max = mid
    TEST_RTYPE(148, remu, 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000)  # max % max = 0

    # Typical large‐value divides
    TEST_RTYPE(149, remu, 0xFFFFFFFF, 2,          1)           # max    % 2 = 1
    TEST_RTYPE(150, remu, 0x80000000, 2,          0)           # 2^31   % 2 = 0
    TEST_RTYPE(151, remu, 0x80000001, 2,          1)           # (2^31+1)% 2 = 1

    # Zero numerator → always 0 (even if divisor = 0xFFFFFFFF)
    TEST_RTYPE(152, remu, 0x00000000, 5,          0x00000000)  # 0 % 5 = 0
    TEST_RTYPE(153, remu, 0x00000000, 0xFFFFFFFF, 0x00000000)  # 0 % max = 0

    # Divide‐by‐zero → remainder = numerator
    TEST_RTYPE(154, remu, 5,           0,          5)           #   5 % 0 = 5
    TEST_RTYPE(155, remu, 0,           0,          0)           #   0 % 0 = 0
    TEST_RTYPE(156, remu, 0xFFFFFFFF, 0,    0xFFFFFFFF)     # max % 0 = max

################################################################################
TEST_FOOTER