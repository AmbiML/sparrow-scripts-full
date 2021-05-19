#!/bin/bash
#
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

RENODE_CONFIG_OUT=${OUT}/renode_configs
OT_EARLGREY_OUT=${OUT}/opentitan/build-out
OT_SHODAN_OUT=${OUT}/sparrow/build-out

if [[ -z "${ROOTDIR}" ]];
then
  echo "Source build/setup.sh first"
  exit 1
fi

cd ${ROOTDIR}
source build/setup.sh

EARLGREY_BOOT_ROM=$(find ${OT_EARLGREY_OUT} -iname "boot_rom_sim_verilator.elf" | head -n 1)
EARLGREY_HELLOWORLD=$(find ${OT_EARLGREY_OUT} -iname "hello_world_sim_verilator.elf" | head -n 1)

mkdir -p ${RENODE_CONFIG_OUT}

gen_platform() {
  python3 sim/opentitan-renode/generate_renode_scripts.py \
    --opentitan-path=hw/opentitan \
    --template-path=sim/opentitan-renode/data \
    --out-dir=${RENODE_CONFIG_OUT} \
    --skip-resc \
    --top ${1}
}

gen_script() {
  python3 sim/opentitan-renode/generate_renode_scripts.py \
    --opentitan-path=hw/opentitan \
    --template-path=sim/opentitan-renode/data \
    --out-dir=${RENODE_CONFIG_OUT} \
    --repl=${RENODE_CONFIG_OUT}/opentitan-$1-gen.repl \
    --boot-rom=$4 \
    --boot-addr 0x8084 \
    --top "$1" \
    --elf-program="$2" \
    --suffix="$3" \
    --skip-repl
}

gen_earlgrey_scripts_for_elfs() {
for elf_file in ${@}; do
  BASENAME=$(basename ${elf_file} .elf)
  echo "Generate earlgrey renode script for ${BASENAME}"
  gen_script earlgrey ${elf_file} gen_${BASENAME} ${EARLGREY_BOOT_ROM}
done
}

gen_sparrow_scripts_for_elfs() {
for elf_file in ${@}; do
  BASENAME=$(basename ${elf_file} .elf)
  echo "Generate sparrow renode script for ${BASENAME}"
  gen_script sparrow ${elf_file} gen_${BASENAME} ${EARLGREY_BOOT_ROM}
done
}

gen_platform earlgrey
EARLGREY_ELFS=$(find ${OT_EARLGREY_OUT} -type f \( -iname "*sim_verilator.elf" ! -iname "*rom*" \))
gen_earlgrey_scripts_for_elfs ${EARLGREY_ELFS}

gen_platform sparrow
SHODAN_ELFS=$(find ${OT_SHODAN_OUT} -type f \( -iname "*sim_verilator.elf" ! -iname "*rom*" \))
gen_sparrow_scripts_for_elfs ${SHODAN_ELFS}