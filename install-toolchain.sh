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

# Install the prebuilt RISC-V GCC/LLVM toolchain.

function clean {
  if [[ ! -f "${PREINSTALL_DIR}/${TOOLCHAIN_TARBALL}" ]]; then
    rm "${DOWNLOAD_DIR}/${TOOLCHAIN_TARBALL}" \
       "${DOWNLOAD_DIR}/${TOOLCHAIN_TARBALL}.sha256sum"
  fi
}

function die {
  echo "$@" >/dev/stderr
  exit 1
}

function try {
  $@ || die "Failed to execute '$@'"
}

if [[ -z "${ROOTDIR}" ]]; then
  echo "Source build/setup.sh first"
  exit 1
fi
if [[ -z "$1" ]]; then
  cat << EOM
Usage: install-toolchain.sh target
Where target is gcc or llvm
EOM
  exit 1
fi

TARGET=${1:-gcc}
TOOLCHAIN_TARBALL=""
case "${TARGET}" in
  gcc)
    TOOLCHAIN_TARBALL="toolchain.tar.gz"
    ;;

  llvm)
    TOOLCHAIN_TARBALL="toolchain_iree_rv32.tar.gz"
    ;;

  *)
    echo "unsupported target: ${TARGET}"
    exit 1
    ;;
esac

trap clean EXIT

# Used by the CI sparrow docker image
PREINSTALL_DIR=/usr/src

if [[ -f "${PREINSTALL_DIR}/${TOOLCHAIN_TARBALL}" ]]; then
  echo "${TOOLCHAIN_TARBALL} stored in the machine at ${PREINSTALL_DIR}"
  DOWNLOAD_DIR=/usr/src
else
  echo "Download ${TOOLCHAIN_TARBALL} from GCS..."
  DOWNLOAD_URL="https://storage.googleapis.com/sparrow-public-artifacts/${TOOLCHAIN_TARBALL}"
  DOWNLOAD_DIR="${OUT}/tmp"
  mkdir -p "${DOWNLOAD_DIR}"

  wget --progress=dot:giga -P "${DOWNLOAD_DIR}" "${DOWNLOAD_URL}"
  wget -P "${DOWNLOAD_DIR}" "${DOWNLOAD_URL}.sha256sum"
  pushd "${DOWNLOAD_DIR}" > /dev/null
  try sha256sum -c "${TOOLCHAIN_TARBALL}.sha256sum"
  popd > /dev/null
fi

try tar -C "${CACHE}" -xf "${DOWNLOAD_DIR}/${TOOLCHAIN_TARBALL}"

# Prepare a newlib-nano directory for the default link of -lc, -lgloss, etc.
# TODO(hcindyl): Remove the duped symlink creation once we switched to a toolchain from CI.
if [[ "${TARGET}" == "llvm" ]]; then
  lib_dir="${CACHE}/toolchain_iree_rv32imf/riscv32-unknown-elf/lib/"
  try mkdir -p "${lib_dir}/newlib-nano"
  try ln -rsf "${lib_dir}/libc_nano.a" "${lib_dir}/newlib-nano/libc.a"
  try ln -rsf "${lib_dir}/libg_nano.a" "${lib_dir}/newlib-nano/libg.a"
  try ln -rsf "${lib_dir}/libm_nano.a" "${lib_dir}/newlib-nano/libm.a"
  try ln -rsf "${lib_dir}/libgloss_nano.a" "${lib_dir}/newlib-nano/libgloss.a"
fi
