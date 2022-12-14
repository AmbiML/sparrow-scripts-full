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
  echo "Usage: download-toolchain.sh <gcc dir> [<TARGET> | GCC | LLVM]"
  exit 1
fi

TOOLCHAIN_TARGET=${2:-GCC}

TOOLCHAIN_GCC_SRC="$1"
TOOLCHAIN_SRC="${OUT}/tmp/toolchain"
LLVM_SRC="${TOOLCHAIN_SRC}/llvm-project"

TOOLCHAINLLVM_TAG="2021.06.18"
TOOLCHAINLLVM_BINUTILS_URL="git://sourceware.org/git/binutils-gdb.git"


TOOLCHAIN_OUT="${CACHE}/toolchain"

if [[ ! "${TOOLCHAIN_TARGET}" == "GCC" ]] &&
  [[ ! "${TOOLCHAIN_TARGET}" == "LLVM" ]]; then
  echo "Unsupported toochain target: ${TOOLCHAIN_TARGET}"
  exit 1
fi

echo "Download toolchain for target ${TOOLCHAIN_TARGET}"

if [[ -d "${TOOLCHAIN_GCC_SRC}" ]]; then
  echo "Remove existing ${TOOLCHAIN_GCC_SRC}..."
  rm -rf "${TOOLCHAIN_GCC_SRC}"
fi
mkdir -p "${TOOLCHAIN_GCC_SRC}"

# Download from the http://github.com/riscv/riscv-gnu-toolchain. For proper
# support of GDB symbol rendering, it requires a tag points to gcc 10.2.
# Use git init and git fetch to avoid creating an extra layer of the source code.
pushd "${TOOLCHAIN_GCC_SRC}" > /dev/null
git init
git remote add origin https://github.com/riscv/riscv-gnu-toolchain
echo "Downloading the GNU toolchain source code from master"
git fetch origin --tags
git reset --hard ${TOOLCHAINLLVM_TAG}
popd > /dev/null

# Update the submodules. The riscv-binutils has to point to upstream binutil-gdb
# regardless of what it is in .gitmodules
pushd "${TOOLCHAIN_GCC_SRC}" > /dev/null
git submodule update --init --jobs=8
if [[ "${TOOLCHAIN_TARGET}" == "LLVM" ]]; then
  cd "riscv-binutils"
  git remote set-url origin "${TOOLCHAINLLVM_BINUTILS_URL}"
  git pull -f origin master --jobs=8 --depth=1
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
