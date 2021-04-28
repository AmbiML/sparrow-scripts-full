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

# Script to run the toy IREE example

QEMU_PATH="${OUT}/host/qemu/riscv64-linux-user"
IREE_SRC="${ROOTDIR}/toolchain/iree"
IREE_BUILD_TOOLCHAIN="${CACHE}/toolchain_iree"
IREE_HOST_TOOLCHAIN="${OUT}/host/iree-build-host"
IREE_RISCV_TOOLCHAIN="${OUT}/host/iree-build-riscv"

# Generate the MLIR executable with iree-translate from iree-build-host.
# The artifact is built with dylib target in this script.
RISCV_TOOLCHAIN_ROOT="${IREE_BUILD_TOOLCHAIN}" \
${IREE_HOST_TOOLCHAIN}/install/bin/iree-translate \
    -iree-mlir-to-vm-bytecode-module -iree-hal-target-backends=dylib-llvm-aot \
    -iree-llvm-target-triple=riscv64 \
    -iree-llvm-target-cpu=sifive-u74 \
    -iree-llvm-target-abi=lp64d \
    ${IREE_SRC}/iree/tools/test/iree-run-module.mlir \
    -o /tmp/iree-run-module-llvm_aot.vmfb

# Execute the iree runtime (iree-run-module) in RISCV Qemu simulator.
IREE_RUN_OUT=$(${QEMU_PATH}/qemu-riscv64 -cpu rv64,x-v=true,x-k=true,vlen=256,elen=64,vext_spec=v1.0 \
    -L ${IREE_BUILD_TOOLCHAIN}/sysroot \
    ${IREE_RISCV_TOOLCHAIN}/iree/tools/iree-run-module --driver=dylib \
    --module_file=/tmp/iree-run-module-llvm_aot.vmfb \
    --entry_function=abs --function_input="i32=-10")
echo ${IREE_RUN_OUT}

# Check the result of running abs(-10).
if [[ ${IREE_RUN_OUT} == *"i32=10" ]]; then
    echo "Smoke test passed"
else
    echo "Smoke test failed with mismatch"
    exit 1
fi
