#! /bin/bash

# Launch gdb talking to a simulator or similar at localhost:3333
#
# ROOTDIR must be set to the top of the sparrow development tree
# (as done by build/setup.sh).

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

TARGET=riscv32-unknown-elf
GDB="${ROOTDIR}"/cache/toolchain/bin/${TARGET}-gdb
PROGRAM=out/sparrow_boot_rom/build-out/multihart_boot_rom/multihart_boot_rom_sim_verilator.elf
REMOTE=localhost:3333

KATA_OUT=out/kata/${TARGET}/debug
MATCHA_OUT=out/matcha/riscv32imc-unknown-none-elf/debug

export SOURCE_DIR=${ROOTDIR}/kata
export BUILD_DIR=$KATA_OUT

# NB: -q suppresses the banner to workaround the banner msg triggering the pager
# NB: auto-start cpu0 & cpu1 but leave cpu2 (VC) halted
exec "${GDB}" -q -cd "${ROOTDIR}" \
  -ex "set pagination off" \
  -ex "directory sw/tock" \
  -ex "file ${PROGRAM}" \
  -ex "set confirm off" \
  -ex "add-symbol-file ${PROGRAM}" \
  -ex "add-symbol-file ${MATCHA_OUT}/matcha_platform" \
  -ex "add-symbol-file ${MATCHA_OUT}/matcha_app" \
  -ex "set pagination on" \
  -ex "target remote ${REMOTE}" \
  -ex "monitor cpu0 IsHalted false" \
  -ex "monitor cpu1 CreateSeL4" \
  -ex "source sim/renode/tools/sel4_extensions/gdbscript.py"
