# Getting Started

## Prerequisites
### Install Toolchain

```bash
./scripts/install_toolchain.sh
```

If you already have a working `riscv32-unknown-elf-*` toolchain in `PATH`, you can skip this.

### Install Verilator

Use the official install instructions:

- <https://verilator.org/guide/latest/install.html>

## Build the Simulator

```bash
make sim
```

This produces the simulator binary under `sim/build/bin/`.

## Build Software
```bash
make sw
```

## Run

```bash
make test
```
