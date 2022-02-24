#! /bin/bash
# Create kata shell socket port based on the renode port number as the input
# argument.

TERM_PORT=${1:-0}
if [[ ${TERM_PORT} -ge 0 ]]; then
  SOCKET_PORT=$((${TERM_PORT} + 3456))
else
  SOCKET_PORT=1337
fi

echo "${SOCKET_PORT}"
