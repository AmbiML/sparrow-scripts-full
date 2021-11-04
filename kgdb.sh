#! /bin/bash

# Launch gdb talking to a simulator or similar at localhost:3333
#
# ROOTDIR must be set to the top of the sparrow development tree
# (as done by build/setup.sh).

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

GDB="${ROOTDIR}"/cache/toolchain/bin/riscv32-unknown-elf-gdb
PROGRAM=out/sparrow_boot_rom/build-out/multihart_boot_rom/multihart_boot_rom_sim_verilator.elf
REMOTE=localhost:3333

# TODO(sleffler): camkes components are loaded as part of capdl-loader;
#   need to calculate offsets

# NB: -q suppresses the banner to workaround the banner msg triggering the pager
exec "${GDB}" -q -cd "${ROOTDIR}" \
  -ex "set pagination off" \
  -ex "directory sw/tock" \
  -ex "file ${PROGRAM}" \
  -ex "set confirm off" \
  -ex "add-symbol-file ${PROGRAM}" \
  -ex "add-symbol-file out/matcha/riscv32imc-unknown-none-elf/debug/matcha_platform" \
  -ex "add-symbol-file out/matcha/riscv32imc-unknown-none-elf/debug/matcha_app" \
  -ex "add-symbol-file out/kata/kernel/kernel.elf" \
  -ex "add-symbol-file out/kata/capdl-loader" \
  -ex "add-symbol-file out/kata/debug_console.instance.bin" \
  -ex "add-symbol-file out/kata/process_manager.instance.bin" \
  -ex "set pagination on" \
  -ex "target remote ${REMOTE}"
