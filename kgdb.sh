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

# Launch gdb talking to a simulator or similar at localhost:3333
#
# ROOTDIR must be set to the top of the sparrow development tree
# (as done by build/setup.sh).

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

TARGET=riscv32-unknown-elf
GDB="${ROOTDIR}"/cache/toolchain/bin/${TARGET}-gdb
PROGRAM=out/sparrow_boot_rom/multihart_boot_rom.elf
REMOTE=localhost:3333

CANTRIP_OUT=out/cantrip/${PLATFORM}/debug
MATCHA_OUT=out/matcha/riscv32imc-unknown-none-elf/debug

USE_SEL4_EXTENSIONS="true"
USE_SEL4_SYMBOL_AUTOSWITCHING="false"

export SOURCE_DIR=${ROOTDIR}/cantrip
export BUILD_DIR=$CANTRIP_OUT

function parseargv {
    local usage="Usage: kgdb.sh [-h|--help] [-S|--no-sel4-extensions] [-a|--sel4-symbol-autoswitching]"
    local args=$(getopt -o hSa --long no-sel4-extensions,symbol-autoswitching,help -n kgdb.sh -- "$@")

    set -- $args

    for i; do
        case "$1" in
            -S|--no-sel4-extensions)
                echo "*** Disabling sel4 extensions"
                USE_SEL4_EXTENSIONS="false"
                shift
                ;;

            -a|--symbol-autoswitching)
                echo "*** Enabling sel4 symbol autoswitching"
                echo "*** Warning: this can cause unexpected behaviors."
                USE_SEL4_EXTENSIONS="true"
                USE_SEL4_SYMBOL_AUTOSWITCHING="true"
                shift
                ;;

            --)
                shift
                break
                ;;

            -h|--help|*)
                echo "$usage" >/dev/stderr
                exit 1
                ;;
        esac
    done
}

function main {
    local -a gdbargs=(
         -ex "set pagination off"
         -ex "directory sw/tock"
         -ex "file ${PROGRAM}"
         -ex "set confirm off"
         -ex "add-symbol-file ${PROGRAM}"
         -ex "add-symbol-file ${MATCHA_OUT}/matcha_platform"
         -ex "add-symbol-file ${MATCHA_OUT}/matcha_app"
         -ex "set pagination on"
         -ex "target remote ${REMOTE}"
         -ex "monitor cpu0 IsHalted false"
    )

    parseargv "$@"

    if [[ "${USE_SEL4_EXTENSIONS}" == "true" ]]; then
        gdbargs+=(
            -ex "monitor cpu1 CreateSeL4 0xffffffee"
            -ex "source sim/renode/tools/sel4_extensions/gdbscript.py"
            -ex "sel4 symbol-autoswitching ${USE_SEL4_SYMBOL_AUTOSWITCHING}"
        )
    fi


    # NB: -q suppresses the banner to workaround the banner msg triggering the pager
    # NB: auto-start cpu0 & cpu1 but leave cpu2 (VC) halted
    exec "${GDB}" -q -cd "${ROOTDIR}" "${gdbargs[@]}"
}

main "$@"
