#!/bin/bash
#
# Copyright 2023 Google LLC
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

# Run a test on the nexus FPGA platform
set -e

BITSTREAM_PATH="$1"
BINARY_PATH="$2"
NEXUS_ID="${NEXUS_ID:-$3}"

if [ $# -lt 2 ] || [ $# -gt 3 ] ; then
cat << EOF
    $0 <bitstream> <binary> [nexus index]
    bitstream: The path to the nexus bitstream.
               This will be copied and loaded to the fpga
    binary: The path to the test binary.
            This will be loaded with the opentitantool utility using the
            bootstrap subcommand
    nexus index: The number assigned to the nexus board that will be used for
                 the test. Include zero padding for numbers less than 10. This
                 arg is optional and will fall back on the NEXUS_ID environment
                 variable.
EOF
exit 1
fi

# Verify no one else is using our UARTs
if fuser "/dev/Nexus-FTDI-${NEXUS_ID}-FPGA-UART"
then
    echo "/dev/Nexus-FTDI-${NEXUS_ID}-FPGA-UART appears to be busy"
fi
if fuser "/dev/Nexus-CP210-FPGA-UART-${NEXUS_ID}"
then
    echo "/dev/Nexus-CP210-FPGA-UART-${NEXUS_ID} appears to be busy"
fi

stty --file="/dev/Nexus-FTDI-${NEXUS_ID}-FPGA-UART" 115200
stty --file="/dev/Nexus-CP210-FPGA-UART-${NEXUS_ID}" 115200

scp \
    "${BITSTREAM_PATH}" \
    "root@nexus${NEXUS_ID}:/mnt/mmcp1/"

# Starting logging the UARTs
cat "/dev/Nexus-FTDI-${NEXUS_ID}-FPGA-UART" > uart.sc.log &
SC_UART_PID=$!
cat "/dev/Nexus-CP210-FPGA-UART-${NEXUS_ID}" > uart.smc.log &
SMC_UART_PID=$!

# Logging cleanup for when the script exits
trap 'kill -INT ${SC_UART_PID} ; kill -INT ${SMC_UART_PID} ; \
      sleep 10 ; \
      kill -KILL ${SC_UART_PID} ; kill -KILL ${SMC_UART_PID}' 0

# zturn exits with 1 even when working correctly. Mask with exit 0
BITSTREAM_NAME=$(basename "${BITSTREAM_PATH}")
ssh \
    "root@nexus${NEXUS_ID}" \
    "/mnt/mmcp1/zturn -d a /mnt/mmcp1/${BITSTREAM_NAME} ; exit 0"

OT_TOOL_PATH=`command -v opentitantool`
NEXUS_JSON_DIR=`dirname "${OT_TOOL_PATH}"`
NEXUS_JSON_PATH="${NEXUS_JSON_DIR}/nexus.json"

opentitantool \
    --conf "${NEXUS_JSON_PATH}" \
    --interface nexus \
    --usb-serial "Nexus-FTDI-${NEXUS_ID}" \
    bootstrap "${BINARY_PATH}"

timeout 300 bash -c 'until grep -q PASS! uart.sc.log ; do
                        echo "Expected log is missing. Wait up to 300s."
                        sleep 10
                    done'

cat -n uart.sc.log
cat -n uart.smc.log

grep -q "PASS!" uart.sc.log
exit $?
