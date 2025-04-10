#!/bin/bash
################################################################################
# This script will build and install the RISC-V toolchain
################################################################################
set -e

# Toolchain name
TOOLCHAIN_NAME=rv64-multilib
TOOLCHAIN_BUILDFLAGS=--enable-multilib
BUILD_JOBS=$(nproc)

# Toolchain install directory
# Toolchain will be installed in $TOOLCHAIN_ROOTPATH/$TOOLCHAIN_NAME directory
TOOLCHAIN_ROOTPATH=$HOME/opt/riscv

################################################################################
# You sould not change anything below this
CLR_RD="\e[31m"
CLR_GR="\e[32m"
CLR_OR="\e[33m"
CLR_NC="\e[0m"

function info() {
    echo -e "${CLR_GR}>> $1${CLR_NC}"
}

function error() {
    echo -e "${CLR_RD}>> $1${CLR_NC}"
}

function warn() {
    echo -e "${CLR_OR}>> $1${CLR_NC}"
}

################################################################################
CWDIR=$(pwd)

# Determine the installation path
TOOLCHAIN_INSTALL_PATH=${TOOLCHAIN_ROOTPATH}/${TOOLCHAIN_NAME}

# Checking for any existing toolchain installation, if found ask user if they want to remove it
if [ -d ${TOOLCHAIN_INSTALL_PATH} ]; then
    warn "Toolchain already installed at ${TOOLCHAIN_INSTALL_PATH}"
    read -p "Do you want to remove it? [y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Removing existing toolchain..."
        rm -rf ${TOOLCHAIN_INSTALL_PATH}
    else
        info "Keeping existing toolchain... Exiting..."
        exit 1
    fi
fi

# Install Prerequisites
info "Installing prerequisites..."
sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev \
    libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build \
    git cmake libglib2.0-dev libslirp-dev

# Download source code
if [ -d riscv-gnu-toolchain ]; then 
    info "riscv-gnu-toolchain already cloned.. reusing..."
else 
    info "Cloning riscv-gnu-toolchain..."
    git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
fi

# Build & installing toolchain
info "Building and installing toolchain..."
mkdir -p riscv-gnu-toolchain/build_${TOOLCHAIN_NAME}
cd riscv-gnu-toolchain/build_${TOOLCHAIN_NAME}
../configure --prefix=${TOOLCHAIN_INSTALL_PATH} ${TOOLCHAIN_BUILDFLAGS}
make -j${BUILD_JOBS}


cd ${CWDIR}

# Cleanup
info "*** Toolchain Installation Successful! ***"
info "Toolchain        : ${TOOLCHAIN_NAME}"
info "Install location : ${TOOLCHAIN_INSTALL_PATH}"
info "-------------------------------------------"
info "1. Make sure to add it to path as follows:"
info "      \$ export PATH=\$PATH:${TOOLCHAIN_INSTALL_PATH}/bin"
info "   Or, You can also add this line to sourceme script"
info "2. You are free to delete the source repo: riscv-gnu-toolchain"
