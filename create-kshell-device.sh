#! /bin/bash
# Create kata shell pty device based on the renode port number as the input
# argument.

TERM_PORT=${1:-0}
if [[ ${TERM_PORT} -gt 0 ]]; then
  TERM_DEV="/tmp/term${TERM_PORT}"
elif [[ ${TERM_PORT} -eq 0 ]]; then
  TERM_DEV="/tmp/term"
else
  TERM_DEV="/tmp/term1337"
fi

echo "${TERM_DEV}"
