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

# Connect to the kata console shell & optionally tee output
# to /tmp/kshell*.log

# Usage: kshell [-l] [port]

LOG_OUTPUT=
if [[ "$1" == "-l" ]]; then
    LOG_OUTPUT="yes"
    shift
fi

PORT=${1:-1234}
DIR_NAME=$(dirname $(realpath $0))
TERM_PORT_INPUT=$((${PORT} - 1234))
SOCKET_PORT=$("${DIR_NAME}/create-kshell-socket-port.sh" ${TERM_PORT_INPUT})

trap "stty sane" 0
stty sane -echo -icanon

echo "Access port: ${SOCKET_PORT}"
if [[ "${LOG_OUTPUT}" == "yes" ]]; then
    socat "TCP:localhost:${SOCKET_PORT}" - | tee /tmp/kshell.$$.log
else
    socat "TCP:localhost:${SOCKET_PORT}" -
fi
