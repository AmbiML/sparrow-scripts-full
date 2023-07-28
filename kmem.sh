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
#
# Note mmio sections do not count against memory usage as they are
# allocated from dedicated memory that does not have physical
# memory backing.
#
# ROOTDIR must be set to the top of the sparrow development tree
# (as done by build/setup.sh).

# Usage: kmem [-d]

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

# NB: should always be set but default anyway
PLATFORM=${PLATFORM:-sparrow}

# Default is a summary of release build.
DETAILS=""
BUILD="release"
KERNEL="--kernel"
VERBOSE=""

function parseargv {
    local usage="Usage: kmem.sh [-h|--help] [-d|--details] [-D|--debug] [-R|--release] [-s|--summary] [-u|--user] [-v|--verbose]"
    local args=$(getopt -o dDRsuv --long details,debug,release,summary,user,verbose,help -n kmem.sh -- "$@")

    set -- $args

    for i; do
        case "$1" in
            -d|--details)
                DETAILS="--details"
                shift
                ;;

            -s|--summary)
                DETAILS=""
                shift
                ;;

            -D|--debug)
                BUILD="debug"
                shift
                ;;

            -R|--release)
                BUILD="release"
                shift
                ;;

            -u|--user)
                KERNEL=""
                shift
                ;;

            -v|--verbose)
                VERBOSE="--verbose"
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

CANTRIP_OUT="${ROOTDIR}/out/cantrip/${PLATFORM}/${BUILD}"
PYTHONPATH="${PYTHONPATH}:${ROOTDIR}/cantrip/projects/capdl/python-capdl-tool"
exec python3 "${ROOTDIR}/cantrip/tools/seL4/kmem-tool/kmem.py" --object-state "${CANTRIP_OUT}/object-final.pickle" ${DETAILS} ${KERNEL} ${VERBOSE}
