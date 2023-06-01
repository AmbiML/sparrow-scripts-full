#!/bin/bash
#
# Copyright 2021 Google LLC
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

# Download the riscv-gnu-toolchain/LLVM source.


if [[ -z "${ROOTDIR}" ]]; then
  echo "Source build/setup.sh first"
  exit 1
fi
if [[ -z "$1" ]]; then
  echo "Usage: download-toolchain.sh <gcc dir> [<TARGET> | GCC | LLVM | KELVIN]"
  exit 1
fi

TOOLCHAIN_TARGET=${2:-GCC}

TOOLCHAIN_GCC_SRC="$1"
TOOLCHAIN_SRC="${OUT}/tmp/toolchain"
LLVM_SRC="${TOOLCHAIN_SRC}/llvm-project"

TOOLCHAIN_TAG="2021.06.18"
TOOLCHAINLLVM_BINUTILS_URL="git://sourceware.org/git/binutils-gdb.git"

if [[ ! "${TOOLCHAIN_TARGET}" == "GCC" ]] &&
  [[ ! "${TOOLCHAIN_TARGET}" == "LLVM" ]] &&
  [[ ! "${TOOLCHAIN_TARGET}" == "KELVIN" ]]; then
  echo "Unsupported toochain target: ${TOOLCHAIN_TARGET}"
  exit 1
fi

echo "Download toolchain for target ${TOOLCHAIN_TARGET}"

if [[ -d "${TOOLCHAIN_GCC_SRC}" ]]; then
  echo "Remove existing ${TOOLCHAIN_GCC_SRC}..."
  rm -rf "${TOOLCHAIN_GCC_SRC}"
fi

# Download from the http://github.com/riscv/riscv-gnu-toolchain. For proper
# support of GDB symbol rendering, it requires a tag points to gcc 10.2.
echo "Downloading the GNU toolchain source code from tag ${TOOLCHAIN_TAG}"
git clone https://github.com/riscv/riscv-gnu-toolchain -b "${TOOLCHAIN_TAG}" \
  "${TOOLCHAIN_GCC_SRC}"

# Update the submodules. The riscv-binutils has to point to upstream binutil-gdb
# regardless of what it is in .gitmodules
pushd "${TOOLCHAIN_GCC_SRC}" > /dev/null

# CentOS7 git does not support parellel jobs.
if [[ "${TOOLCHAIN_TARGET}" == "KELVIN" ]]; then
  git submodule update --init riscv-*
else
  git submodule update --init --jobs=8 riscv-*
fi

if [[ "${TOOLCHAIN_TARGET}" == "LLVM" ]]; then
  cd "riscv-binutils"
  git remote set-url origin "${TOOLCHAINLLVM_BINUTILS_URL}"
  git pull -f origin master --jobs=8 --depth=1
  git checkout FETCH_HEAD
fi

# Update riscv-binutils for kelvin to binutils 2.40
if [[ "${TOOLCHAIN_TARGET}" == "KELVIN" ]]; then
  cd "riscv-binutils"
  git remote set-url origin "${TOOLCHAINLLVM_BINUTILS_URL}"
  git fetch -f origin binutils-2_40 --depth=1
  git checkout FETCH_HEAD
fi
popd > /dev/null

# Download LLVM project if necessary. Always pull from main ToT.
if [[ "${TOOLCHAIN_TARGET}" == "LLVM" ]]; then
  if [[ -d "${LLVM_SRC}" ]]; then
    echo "Removing existing ${LLVM_SRC}..."
    rm -rf "${LLVM_SRC}"
  fi
  mkdir -p "${LLVM_SRC}"
  pushd "${LLVM_SRC}" > /dev/null
  git init
  git remote add origin https://github.com/llvm/llvm-project
  git pull origin main --jobs=8 --depth=1
  popd > /dev/null
fi

# Patch Kelvin custom ops
if [[ "${TOOLCHAIN_TARGET}" == "KELVIN" ]]; then
  pushd "${TOOLCHAIN_GCC_SRC}/riscv-binutils" > /dev/null
  git apply "${ROOTDIR}/build/patches/kelvin/0001-Kelvin-riscv-binutils-patch.patch"
  cp "${ROOTDIR}/build/patches/kelvin/kelvin-opc.h" "include/opcode/kelvin-opc.h"
  cp "${ROOTDIR}/build/patches/kelvin/kelvin-opc.c" "opcodes/kelvin-opc.c"
  popd > /dev/null
fi
