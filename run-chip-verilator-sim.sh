#! /bin/bash
# Run verilator testbench simulation.

if [[ $# -lt 5 || $1 == "--help" ]]; then
  echo "Usage: run-chip-verilator-sim.sh <verilator testbench> <rom binary> <flash binary> <otp binary> <smc binary> [OPTIONS]"
  exit 0
fi

VCHIP_TB=$1
ROM_BIN=$2
FLASH_BIN=$3
OTP_BIN=$4
RAM_SMC_BIN=$5

shift 5

if [[ ! -f $(realpath ${VCHIP_TB}) ]]; then
  echo "Verilator testbench not found. Please run \`m matcha_hw_verilator_sim\` or generate the testbench first."
  exit 1
fi

if [[ ! -f $(realpath ${ROM_BIN}) ]] || [[ ! -f $(realpath ${FLASH_BIN}) ]] ||
  [[ ! -f $(realpath ${OTP_BIN}) ]] || [[ ! -f $(realpath ${RAM_SMC_BIN}) ]]; then
  echo "Software binaries not found. Please run \`m opentitan_sw_verilator_sim\` or generate the SW binaries first."
  exit 1
fi

${VCHIP_TB} \
  "--meminit=rom,${ROM_BIN}" \
  "--meminit=flash,${FLASH_BIN}" \
  "--meminit=otp,${OTP_BIN}" \
  "--meminit=ram_smc,${RAM_SMC_BIN}" $@
