#! /bin/bash
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
