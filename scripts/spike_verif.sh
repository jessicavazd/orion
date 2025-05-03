#! /bin/bash
################################################################################
# A scipt to run orionsim with spike verification
################################################################################
set -e      # Exit immediately if a command exits with a non-zero status
# set -x      # Print each command before executing it (For debuigging)

# Define colors for output
CLR_RD="\033[0;31m"
CLR_GR="\033[0;32m"
CLR_NC="\033[0m"

# Check if spike and orionsiom are installed
if ! command -v spike > /dev/null 2>&1; then
    printf "${CLR_RD}ERROR:${CLR_NC} spike could not be found\n"
    exit 1
fi
if ! command -v orionsim > /dev/null 2>&1; then
    printf "${CLR_RD}ERROR:${CLR_NC} orionsim could not be found\n"
    exit 1
fi

# Default values
ELF=None
BUILD_DIR=build
SPIKE_FLAGS=''
ORIONSIM_FLAGS=''

# Simple CLI override parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --elf)
            ELF="$2"
            shift 2
            ;;
        --build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        --spike-flags)
            SPIKE_FLAGS="$2"
            shift 2
            ;;
        --orionsim-flags)
            ORIONSIM_FLAGS="${ORIONSIM_FLAGS} $2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Check if ELF file is provided
if [ "$ELF" == "None" ]; then
    echo "No ELF file provided. Please provide an ELF file using --elf option."
    exit 1
fi

# Set dependent variables
SPIKE_LOG=${BUILD_DIR}/spike.log
ORIONSIM_LOG=${BUILD_DIR}/orionsim.log
DIFF_FILE=${BUILD_DIR}/run_diff.log

# Additional flags to generate logs
SPIKE_FLAGS="${SPIKE_FLAGS} --log-commits"
ORIONSIM_FLAGS="${ORIONSIM_FLAGS} --log ${ORIONSIM_LOG} --log-format spike"

# Execute Spike
echo "Running spike (ELF: ${ELF})"
echo "$ spike ${SPIKE_FLAGS} ${ELF}"
spike ${SPIKE_FLAGS} ${ELF} 2>&1 | tail -n +6 > ${SPIKE_LOG}

# Execute orionsim
EXEC_HEX=${BUILD_DIR}/$(basename "${ELF}" .elf).hex
if [ ! -f ${EXEC_HEX} ]; then
    echo "Error: ${EXEC_HEX} not found. (required for orionsim)"
    exit 1
fi
echo "Running Orionsim (Hex: ${EXEC_HEX})"
echo "$ orionsim ${ORIONSIM_FLAGS} ${EXEC_HEX}"
orionsim ${ORIONSIM_FLAGS} ${EXEC_HEX} || true

# Check if the logs are identical
diff -y --suppress-common-lines --width=140 ${SPIKE_LOG} ${ORIONSIM_LOG} | expand -t 8 > ${DIFF_FILE}

# Search for differences in the logs
grep -qE '\||<|>' ${DIFF_FILE} && \
    printf "${CLR_RD}[!] Verification failed: Differences found${CLR_NC}\n" && exit 1 || \
    printf "${CLR_GR}[+] Verification success: No differences found in logs${CLR_NC}\n"
