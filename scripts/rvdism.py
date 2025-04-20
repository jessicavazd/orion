#!/usr/bin/env python3
################################################################################
# Script to disassemble RISC-V instructions
# 1) CLI Usage: 
#   riscv_dism.py <hex_instruction>
# 
# 2) Piped Usage:
#   <command> | riscv_dism.py
# 
# Using with GTKWave:
#   right click on a signal -> Data Format 
#   -> Translate filter process -> Enable and Select
#
# Adapted from: https://gist.github.com/saursin/295f720123de0437e76767b7feaffbab
################################################################################
import sys
import argparse
import tempfile
import subprocess

RISCV_TOOL_PREFIX   = "riscv64-unknown-elf-"
DEFAULT_MARCH       = "rv32i"

def disassemble_instr(instr_hex, march, riscv_tool_prefix):
    instr_hex = instr_hex.lower().replace('0x', '')

    with tempfile.TemporaryDirectory() as tmpdir:
        asm_file = f"{tmpdir}/asm.S"
        elf_file = f"{tmpdir}/out.elf"
        bin_file = f"{tmpdir}/out.bin"
        
        with open(asm_file, "w") as f:
            f.write(f".text\n.word 0x{instr_hex}\n")

        # Compile the assembly to ELF
        subprocess.run([f"{riscv_tool_prefix}as", f"--march={march}", asm_file, "-o", elf_file], check=True)

        # Disassemble the ELF file
        subprocess.run([f"{riscv_tool_prefix}objcopy", "-O", "binary", elf_file, bin_file], check=True)

        # Disassemble the binary file
        result = subprocess.run(
            [f"{riscv_tool_prefix}objdump", "-D", "-b", "binary", "-m", f"riscv:{march[:4]}", bin_file],
            stdout=subprocess.PIPE,
            check=True,
            text=True
        )
        # print('-'*80+'\n'+result.stdout+'-'*80+'\n')

        instr, args, comment = None, [], ""
        for line in result.stdout.splitlines():
            line = line.strip()
            if line == "":
                continue
            if line.startswith("0:"):   # Instruction line
                # Extract comment
                if "#" in line:
                    comment = line.split("#")[1].strip()
                    line = line.split("#")[0].strip()

                tok = line.split('\t')[2:]
                instr = tok[0]
                args = tok[1].split(',') if len(tok) > 1 else []
                break

        # print(f'DEBUG: `{instr_hex}` => `{instr}`, `{args}`, `{comment}`')
    
    return instr, args, comment


def dism2str(instr, args, comment):
    txt = f"{instr} {', '.join(args)}"
    if comment:
        txt += f" # {comment}"
    return txt


def main_stdin():
    # Read from stdin: can be used with GTKWave
    f_in = sys.stdin
    f_out = sys.stdout
    while True:
        line = f_in.readline().strip()

        if not line:    # EOF
            break
        
        if 'x' in line: # Simulation X's
            f_out.write(line)
            f_out.flush()
            continue

        instr, args, comment = disassemble_instr(line, DEFAULT_MARCH, RISCV_TOOL_PREFIX)
        dism = dism2str(instr, args, comment)
        f_out.write(f"{dism}\n")
        f_out.flush()


def main_cli():
    # Command line
    parser = argparse.ArgumentParser(description="Disassemble RISC-V instructions")
    parser.add_argument("hex_instr", type=str, help="Hexadecimal instruction to disassemble")
    parser.add_argument("--march", type=str, default=DEFAULT_MARCH, help=f"RISC-V architecture (default: {DEFAULT_MARCH})")
    parser.add_argument("--riscv_tool_prefix", type=str, default=RISCV_TOOL_PREFIX, help=f"RISC-V tool prefix (default: {RISCV_TOOL_PREFIX})")
    args = parser.parse_args()
    
    hex_instr = args.hex_instr
    
    instr, args, comment = disassemble_instr(hex_instr, args.march, args.riscv_tool_prefix)
    dism = dism2str(instr, args, comment)
    print(f"{dism}")


if __name__ == '__main__':
    try:
        # Check if piped input is provided
        if not sys.stdin.isatty():      # command is piped
            main_stdin()
        else:
            main_cli()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
