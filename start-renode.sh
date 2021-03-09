#!/bin/bash

if [[ -z "${ROOTDIR}" ]]; then
    echo "Source build/setup.sh first"
    exit 1
fi

if [[ ! -z "$1" ]]; then
    export SCRIPT_NAME="$1"
fi

screen -c "${ROOTDIR}/scripts/screenrc"
