#!/bin/bash

# Ensure Bash 4+
if ((BASH_VERSINFO[0] < 4)); then
    echo "This script requires Bash version >= 4"
    exit 1
fi

TEST_LOG="${ORION_HOME}/test.log"
: > "$TEST_LOG"

declare -A test_results

n_total=0
n_failed=0

# Run all tests and log output
echo "[+] Running Orion tests"
{
    echo "======================================="
    echo "              Orion Tests              "
    echo "======================================="
    echo "Ran on: $(date '+%Y-%m-%d %H:%M:%S')"

    for testdir in ${ORION_HOME}/test/*/; do
        if [ -d "$testdir" ] && [ "$(basename "$testdir")" != "include" ]; then
            ((n_total++))
            testname=$(basename "$testdir")
            printf "\n------------------------------------------------------------\n"
            printf "[+] Compiling test: $testname\n"
            make -C "$testdir" clean build
            printf "\n[+] Running test: $testname\n"

            if make -C "$testdir" run-verif ORIONSIM_FLAGS="--verbosity 1"; then
                test_results["$testname"]="PASS"
            else
                test_results["$testname"]="FAIL"
                ((n_failed++))
            fi
        fi
    done
} > "$TEST_LOG" 2>&1
echo "[+] Tests completed (total: $n_total)"

# Final report — this is live in terminal and also appended to log
{
    echo "---------------------------------------"
    echo "              Test Report              "
    echo "---------------------------------------"
    for name in "${!test_results[@]}"; do
        printf " %-30s %s\n" "$name" "${test_results[$name]}"
    done

    echo "---------------------------------------"
    echo "Tests Passed: $((n_total - n_failed))"
    echo "Tests Failed: $n_failed"
    echo "Total Tests : $n_total"
} | tee -a "$TEST_LOG"

echo "[+] All tests completed"
echo "[+] See detailed log at $TEST_LOG"
