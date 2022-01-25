#! /bin/bash
# Create renode port command for sparrow.resc based on the renode port number as
# the input argument.

PORT=${1:-1234}
DIR_NAME=$(dirname $(realpath $0))
TERM_PORT_INPUT=$((${PORT} - 1234))
TERM_DEV=$(${DIR_NAME}/create-kshell-device.sh ${TERM_PORT_INPUT})

if [[ ${TERM_PORT_INPUT} -ge 0 ]]; then
  GDB_PORT=$((${TERM_PORT_INPUT} + 3333))
else
  GDB_PORT=4670  # 3333 + 1337
fi

echo "\\\$term_port = \\\"${TERM_DEV}\\\"; \\\$gdb_port = ${GDB_PORT};"
