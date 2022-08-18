#! /bin/bash
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

# This script is derived from work by mwitkowski@antmicro.com

# Script for building a CAmkES test setup using the minimal bits from
# KataOS. This is meant for testing kata-os-common portability and as
# a pathway to public use of the Rust code bits.
#
# This script assumes you have a gnu toolchain setup for the target
# platform and the associated "bin" dir in your shell's search path.
# The rust compiler likewise must be in your search path; the script
# suggests using rustup to request target support.
#
# Beware the KataOS Rust code currently uses a nightly build of Rust.
# Check projects/kata/apps/system/rust.cmake for cargo usage.
#
# The riscv* and arm/aarch* targets are build tested and in some cases
# tested under simulation. The x86* targets are untested and unsupported.
# There are many arm target flavors and only the basic stuff may work;
# in particular don't expect any hypervisor support to work without effort.

# TODO(sleffler): maybe add install-* scripts for necessary toolchains
# TODO(sleffler): maybe import dependent simulators as needed: qemu, spike, renode

TARGET_ARCH=${1:-aarch64}
EXTRA_INIT_ARGS=
MACHINE=

case ${TARGET_ARCH} in
arm|aarch32)
    EXTRA_INIT_ARGS="${EXTRA_INIT_ARGS} -DSIMULATION=TRUE -DAARCH32=TRUE"
    CROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX:-"arm-none-eabi-"}
    RUST_TARGET=${RUST_TARGET:-"arm-unknown-linux-gnueabi"}
    PLATFORM=${PLATFORM:-"omap3"}
    ;;
aarch64)
    EXTRA_INIT_ARGS="${EXTRA_INIT_ARGS} -DSIMULATION=TRUE -DAARCH64=TRUE"
    CROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX:-"aarch64-none-linux-gnu-"}
    RUST_TARGET=${RUST_TARGET:-"${TARGET_ARCH}-unknown-none"}
    PLATFORM=${PLATFORM:-"rpi3"}
    MACHINE=${MACHINE:-"raspi3b"}
    ;;
riscv32)
    # https://docs.sel4.systems/Hardware/spike.html
    # assumes --enable-multilib toolchain
    EXTRA_INIT_ARGS="${EXTRA_INIT_ARGS} -DRISCV32=TRUE"
    CROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX:-"riscv32-unknown-elf-"}
    RUST_TARGET=${RUST_TARGET:-"riscv32imac-unknown-none-elf"}
    PLATFORM=${PLATFORM:-"spike"}
    ;;
riscv64)
    # https://docs.sel4.systems/Hardware/spike.html
    # assumes --enable-multilib toolchain
    EXTRA_INIT_ARGS="${EXTRA_INIT_ARGS} -DRISCV64=TRUE"
    CROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX:-"riscv64-unknown-linux-gnu-"}
    RUST_TARGET=${RUST_TARGET:-"riscv64imac-unknown-none-elf"}
    PLATFORM=${PLATFORM:-"spike"}
    ;;
esac

BUILD_DIR="build-${TARGET_ARCH}"

# Export required variables
# TODO: requiring SEL4_DIR & SEL4_OUT_DIR in the environment is
#   awkward; maybe add fallback/defaults in the build glue

export ROOTDIR="$(pwd)"
export KATA_RUST_VERSION="nightly-2021-11-05"
export SEL4_DIR="${ROOTDIR}/kernel"
export SEL4_OUT_DIR="${ROOTDIR}/${BUILD_DIR}/kernel"

# NB: the gnu toolchain is expected to be in your shell search PATH; e.g.
# cd ~
# wget https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz
# tar xf gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz
# PATH=~/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu/bin:$PATH

rustup --version >/dev/null 2>&1 || {
    cat <<EOF
It appears you don't have the rust installer on this system; please check here:

    https://www.rust-lang.org/tools/install

for help getting started.
EOF
    exit 1
}
rustup toolchain list | grep -q "${KATA_RUST_VERSION}" || {
    cat <<EOF
It appears your rust toolchains do not include version ${KATA_RUST_VERSION}, this is
required to build this software. Use something like:

    rustup toolchain add ${KATA_RUST_VERSION}

to add the necessary version.,
EOF
    exit 1
}
rustup "+${KATA_RUST_VERSION}" target list | grep installed | grep -q "${RUST_TARGET}" || {
    cat <<EOF
It appears your rust toolchain is not setup for ${RUST_TARGET}, use something like:

    rustup target add --toolchain ${KATA_RUST_VERSION}-x86_64-unknown-linux-gnu ${RUST_TARGET}

to add support for ${RUST_TARGET}.
EOF
    exit 1
}

# TODO(sleffler): this is slow, maybe cache result
pip list 2>/dev/null | grep -q -i tempita || {
    cat <<EOF
It appears your python setup lacks the tempita module; this is necessary to build this software.
Something like:

    pip install tempita

should install the necessary module.
EOF
}

# Run cmake to build the ninja files
test -f ${BUILD_DIR}/build.ninja || {
    mkdir -p ${BUILD_DIR}
    (cd ${BUILD_DIR} && ../init-build.sh \
        -DCROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX} \
        -DRUST_TARGET=${RUST_TARGET} \
        -DPLATFORM=${PLATFORM} \
        -DCAPDL_LOADER_APP=kata-os-rootserver \
        -DSIMULATION=TRUE \
        ${EXTRA_INIT_ARGS})
}

# Run ninja to do the actual build
ninja -C ${BUILD_DIR} -j$(nproc)

echo "To run the simulator use: (cd ${BUILD_DIR} && ./simulate -M ${MACHINE})"
