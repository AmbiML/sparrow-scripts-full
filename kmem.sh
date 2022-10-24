#! /bin/bash
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

# CAmkES system image memory analyzer.

# Analyze the CAmkES-generated capDL spec for memory use.
# By default the memory foottprint of each component is displayed.
# The -d option will give a breakdown by memory type:
#  elf          .text + .data
#  bss          .bss
#  ipc_buffer   CAmkES per-thread ipc_buffer's
#  stack        CAmkES per-thread stack
#  bootinfo     Bootinfo page passed by the rooteserver
#  mmio         MMIO region (backed by devivce memory)
#  copyregion   VSpace region (w/o backing memory)
#
# Note mmio + copyregion sections do not count against memory usage as
# they are allocated from dedicated memory that does not have physical
# memory backing.
#
# TODO: account for system resources
#
# ROOTDIR must be set to the top of the sparrow development tree
# (as done by build/setup.sh).

# Usage: kmem [-d]

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

TARGET=${TARGET:-riscv32-unknown-elf}

# Default is a summary of release build.
DETAILS="0"
BUILD="release"

function parseargv {
    local usage="Usage: kmem.sh [-h|--help] [-d|--details] [-D|--debug] [-R|--release] [-s|--summary]"
    local args=$(getopt -o dDRs --long details,debug,release,summary,help -n kmem.sh -- "$@")

    set -- $args

    for i; do
        case "$1" in
            -d|--details)
                DETAILS="1"
                shift
                ;;

            -s|--summary)
                DETAILS="0"
                shift
                ;;

            -D|--debug)
                BUILD="wdebug"
                shift
                ;;

            -R|--release)
                BUILD="release"
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

parseargv "$@"

CANTRIP_OUT="${ROOTDIR}/out/cantrip/${TARGET}/${BUILD}"
exec awk -f "${ROOTDIR}/scripts/mem.awk" "${CANTRIP_OUT}/system.cdl" DETAILS="${DETAILS}"
