# Orion
A configurable RISC-V SoC platform based on the OrionCore

# Prerequisites
```bash
[TBA]
```

# Compiling OrionSim
```bash
# setup the environment variables
$ source sourceme

# Compile
$ make -j`nproc`
```

# Running a program
```bash
# Change to test directory
$ cd sw/tests/hello

# Compile the test
$ make

# Run with spike verification enabled
$ make run-verif TRACE=1
Running hello.elf on Spike and Orionsim
spike --isa=rv32i -m0x10000:0x10000 --log-commits build/hello.elf 2>&1 | tail -n +6 > build/spike.log
orionsim -t --trace-file /home/jessica16/work/orion/trace.fst --log build/orionsim.log --log-format spike build/hello.hex || true
  ____       _              _____ _
 / __ \     (_)            / ____(_)
| |  | |_ __ _  ___  _ __ | (___  _ _ __ ___
| |  | | '__| |/ _ \| '_ \ \___ \| | '_ ` _ \ 
| |__| | |  | | (_) | | | |____) | | | | | | |
 \____/|_|  |_|\___/|_| |_|_____/|_|_| |_| |_|
==================================================
[+] Initializing simulator
[+] Opening trace file: /home/jessica16/work/orion/trace.fst
[+] Opening simulation log file: build/orionsim.log
[+] Setting log format to: spike
[+] Loading hex file: build/hello.hex
[+] Loaded 164 bytes in memory
[+] Starting simulation
[+] Resetting SoC
----------------------------------------
Hello World!
 -- from Orion Core

----------------------------------------
[+] Simulation finished @ 608 cycles
[+]   EBreak hit at PC: 0x00010058
[+] Closed trace file
[+] Verification success: No differences found in logs
```

---
## TODO:
- [x] Implement a basic pipeline (without data dep handling, no stalls, not branches)
- [x] Implement forwarding to handle data dependencies.

