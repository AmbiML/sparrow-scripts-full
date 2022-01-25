#! /bin/bash
# Connect to the kata console shell

PORT=${1:-1234}
DIR_NAME=$(dirname $(realpath $0))
TERM_PORT_INPUT=$((${PORT} - 1234))
TERM_DEV=$(${DIR_NAME}/create-kshell-device.sh ${TERM_PORT_INPUT})
echo "Access ${TERM_DEV}"
stty sane -echo -icanon; socat - "${TERM_DEV}",raw; stty sane
