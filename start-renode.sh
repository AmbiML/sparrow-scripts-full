#!/bin/bash

if [[ ! -z "$1" ]]; then
    export SCRIPT_NAME="$1"
fi

screen -c "${ROOTDIR}/scripts/screenrc"
