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

# Create renode port command for sparrow.resc based on the renode port number as
# the input argument.

PORT=${1:-1234}
DIR_NAME=$(dirname $(realpath $0))
TERM_PORT_INPUT=$((${PORT} - 1234))
SOCKET_PORT=$("${DIR_NAME}/create-kshell-socket-port.sh" ${TERM_PORT_INPUT})

if [[ ${TERM_PORT_INPUT} -ge 0 ]]; then
  GDB_PORT=$((${TERM_PORT_INPUT} + 3333))
else
  GDB_PORT=4670  # 3333 + 1337
fi

echo "\\\$term_port = ${SOCKET_PORT}; \\\$gdb_port = ${GDB_PORT};"
