#! /bin/bash
# Install the rust toolchain to specified version and variant

if [[ "$#" -ne 3 || $1 == "--help" ]]; then
  echo "Usage: install-rust-toolchain.sh <rust dir> <build version|rust-toolchain path> <target>"
  exit 1
fi

RUST_DIR=$1

BUILD_TOOLCHAIN=$2
TARGET=$3

RUSTUP_BIN="${RUST_DIR}/bin/rustup"

mkdir -p "${RUST_DIR}"

if [[ ! -f "${RUSTUP_BIN}" ]]; then
  bash -c 'curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path'
fi

if [[ -f "${BUILD_TOOLCHAIN}" ]]; then
  BUILD_PROJECT=$(dirname $(realpath "${BUILD_TOOLCHAIN}"))
  echo "Build rust toolchain specified for project ${BUILD_PROJECT}..."
  cd "${BUILD_PROJECT}"; "${RUSTUP_BIN}" target add "${TARGET}"
else
  echo "Build specified toolchain ${BUILD_TOOLCHAIN}..."
  "${RUSTUP_BIN}" "+${BUILD_TOOLCHAIN}" target add "${TARGET}"
fi
