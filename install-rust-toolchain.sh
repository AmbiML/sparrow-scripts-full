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

# Install the rust toolchain to specified version and variant

RUSTUP="${RUSTDIR}/bin/rustup"

function die {
    echo "$@" >/dev/stderr
    exit 1
}

function try {
    echo "$@"
    "$@" || die "Failed to execute '$@': exited with return code $?"
}

function in-dir {
    local directory="$1"; shift
    local exitcode=""

    echo "Entering directory ${directory}"
    (cd "$directory" && "$@")
    exitcode="$?"
    echo "Leaving directory ${directory}"

    if [[ "${exitcode}" != "0" ]]; then
        die "Failed to execute '$@': exited with return code ${exitcode}"
    fi
}

function main {
    local usage="Usage: install-rust-toolchain.sh [-v <version> | -p <project-dir>] <target-to-install>"
    local args=$(getopt -o hv:p: \
                        --long help,version:,project: \
                        -n install-rust-toolchain.sh -- "$@")
    eval set -- "$args"

    local version=""
    local project_dir=""

    while true; do
        case "$1" in
            -v|--version)
                version="$2"
                shift
                shift
                ;;

            -p|--project)
                project_dir="$2"
                shift
                shift
                ;;

            -h|--help)
                die "$usage"
                ;;

            --)
                shift
                break
                ;;
        esac
    done

    if [[ ! -z "${version}" && ! -z "${project_dir}" ]]; then
        echo "${usage}"
        echo
        die "-p and -v are mutually exclusive."
    fi

    local target="$1"; shift
    try mkdir -p "${RUSTDIR}"

    if [[ ! -f "${RUSTUP}" ]]; then
        local yesorno=""
        echo "========================================================================"
        echo "Rustup not found locally -- do you want to install it?"
        echo
        echo "Please verify that you understand this will fetch binaries"
        echo "from potentially untrusted sources. Googlers *must* use"
        echo "internally verified builds of the rust compiler toolchains from"
        echo "the internal toolchain tarball repository instead. Do not use this"
        echo "tool to install Rust locally!"
        echo
        read -p "Type YES (in all caps) to proceed: " yesorno

        [[ "${yesorno}" != "YES" ]] && die "User did not indicate agreement."
        try "${ROOTDIR}/scripts/thirdparty/rustup-install.sh" -y
    fi

    if [[ -f "${project_dir}" ]]; then
        # The project specifies its own version of the rust toolchain, and the
        # user is pointing to its specification files, so let rustup use that to
        # install the needed toolchain.

        local project_dir=$(dirname $(realpath "${project_dir}"))
        echo "Installing the rust toolchain for project ${project_dir}..."
        try in-dir "${project_dir}" "${RUSTUP}" target add "${target}"
    elif [[ ! -z "${version}" ]]; then
        # We're being asked to install a specific version of the rust toolchain.

        echo "Installing rust toolchain ${version} for target ${target}..."
        try "${RUSTUP}" "+${version}" target add "${target}"
    else
        die "One of -p or -v must be specified."
    fi
}

if [[ "$EUID" == 0 ]]; then
    die "This script must NOT be run as root."
fi

if [[ -z "${ROOTDIR}" || -z "${RUSTDIR}" ]]; then
    die "Source build/setup.sh first"
fi

main "$@"
