#! /bin/bash
# Connect to the kata console shell

PORT=${1:-1234}
DIR_NAME=$(dirname $(realpath $0))
TERM_PORT_INPUT=$((${PORT} - 1234))
SOCKET_PORT=$("${DIR_NAME}/create-kshell-socket-port.sh" ${TERM_PORT_INPUT})
echo "Access port: ${SOCKET_PORT}"
stty sane -echo -icanon; socat "TCP:localhost:${SOCKET_PORT}" -; stty sane
