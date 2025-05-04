
#define TEST_RTYPE(test_num, testop, x, y, exp) \
_test_ ## test_num: \
    li   a0, test_num; \
    li   x1, x; \
    li   x2, y; \
    testop x3, x1, x2; \
    li   x4, exp; \
    bne  x3, x4, _test_fail \

#define TEST_FOOTER \
_test_pass: \
    /* all tests passed → hang here */ \
    li   a0, 0; \
    j _exit; \
_test_fail: \
    /* test failed → hang here */ \
    /* a0 contains the test number that failed */ \
    j _exit;
