#!/bin/bash
#
# Copyright 2022 Google LLC
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

# Run spike simulation on springbok ELFs

if [[ -z "${ROOTDIR}" ]]; then
  echo "Source build/setup.sh first"
  exit 1
fi

if [[ ! -f "${OUT}/host/spike/bin/spike" ]]; then
  echo "run \`m -j64 spike\` first"
  exit 1
fi

if [[ "$#" -eq 0 || $1 == "--help" ]]; then
  echo "Usage: run-spike-springbok.sh <elf path>"
  exit 0
fi

# spike CLI options:
# -m<a:m,b:n>: specifies the memory layout. Springbok currently has 16MB TCM 
# at 0x3400_0000
# --varch: specifies the v-ext configuration w.r.t. vlen and elen.
# --pc: ELF entry point. Set at the beginning of IMEM.
"${OUT}/host/spike/bin/spike" -m0x34000000:0x1000000 \
 --varch=vlen:512,elen:32 --pc=0x34000000 $@
