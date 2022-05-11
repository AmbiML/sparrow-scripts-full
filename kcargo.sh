#! /bin/bash

# Script for running Sparrow cargo outside the build; useful
# for doing things like kcargo tree or kcargo clippy.

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

# HACK: sel4-config needs a path to the kernel build which could be
#   in debug or release
export SEL4_OUT_DIR="$ROOTDIR/out/kata/riscv32-unknown-elf/debug/kernel/"
if [[ ! -d "${SEL4_OUT_DIR}/gen_config" ]]; then
    echo "No kernel build found at ${SEL4_OUT_DIR}; build a kernel first"
    exit 2
fi

CARGO="${CARGO_HOME}/bin/cargo +${KATA_RUST_VERSION}"
CARGO_TARGET="--target riscv32imac-unknown-none-elf"
CARGO_OPTS='-Z unstable-options -Z avoid-dev-deps'

export RUSTFLAGS='-Z tls-model=local-exec'

cmd=${1:-build}
case "$1" in
fmt)
      ${CARGO} $*;;
""|-*)
      # TODO(sleffler): maybe set --target-dir to avoid polluting the src tree
      ${CARGO} build ${CARGO_OPTS} ${CARGO_TARGET};;
*)
      ${CARGO} $* ${CARGO_OPTS} ${CARGO_TARGET};;
esac
