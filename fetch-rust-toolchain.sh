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

# Fetches the rust toolchain from cloud storage

PUBLIC_ARTIFACTS_PATH="gs://sparrow-public-artifacts"
PUBLIC_ARTIFACTS_URL="https://storage.googleapis.com/sparrow-public-artifacts"

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

function list-tarballs {
    if [[ "$EUID" == 0 ]]; then
        die "This script must NOT be run as root."
    fi
    if ! hash gsutil 2>/dev/null; then
        die "Google cloud SDK is not installed."
    fi

    echo "Available tarballs:"
    echo
    gsutil ls "${PUBLIC_ARTIFACTS_PATH}/rust_toolchain*.tar.xz"
}

function generate-tarball-name {
    local version="$1"; shift
    if [[ -z "${version}" ]]; then
        die "No version specified."
    fi

    echo "rust_toolchain_${version}.tar.xz"
}

function get-original-name {
    local tarball="$1"; shift
    cat "${tarball}.sha256sum" |awk '{ print $2 }'
}

function download-tarball {
    local version="$1"; shift
    local tarball="$(generate-tarball-name ${version})"
    local checksum="${tarball}.sha256sum"

    try mkdir -p "${OUT}"

    try wget --progress=dot:giga -O "${OUT}/${tarball}" "${PUBLIC_ARTIFACTS_URL}/${tarball}"
    try wget -O "${OUT}/${checksum}" "${PUBLIC_ARTIFACTS_URL}/${checksum}"

    # Workaround the fact that we use the datestamped version of the filename
    # at sha256sum creation time. IOW, "latest" is a symbolic name to make
    # fetching easier, so we have to rename the tarball to the original name.
    # Conveniently, this also allows us to determine which tarball is currently
    # set as the latest in storage.
    if [[ "${version}" == "latest" ]]; then
        local original_name=$(get-original-name "${OUT}/${tarball}")
        try mv "${OUT}/${tarball}" "${OUT}/${original_name}"
        try mv "${OUT}/${checksum}" "${OUT}/${original_name}.sha256sum"
        tarball="${original_name}"
        checksum="${original_name}.sha256sum"
    fi

    try in-dir "${OUT}" sha256sum -c "${checksum}"
    try mkdir -p "${CACHE}"
    try tar -C "${CACHE}" -xf "${OUT}/${tarball}"
}

function show-usage {
    cat >/dev/stderr <<EOF
Usage: fetch-rust-toolchain.sh <-d|-l> [-v <date|latest>]

Fetches, verifies, and untars Rust toolchain tarballs from upstram cloud storage
into cache/.

Options:
  -l | --list        List available rust tarballs. Note: this requires the
                         Google Cloud SDK to be installed and logged in.
  -d | --download    Download a tarball. If -v is not provided, assumes
                         "latest".
  -v <date|latest> | --version <date|latest>
                     Download either the tarball of the specified version, or
                         the latest one from upstream storage. If this option is
                         not specified, defaults to "latest".
EOF
}

function main {
    local usage="Usage: install-rust-toolchain.sh [-d|-l|-v <datestamp>]"
    local args=$(getopt -o hdlv: \
                        --long help,download,list:,version: \
                        -n fetch-rust-toolchain.sh -- "$@")
    eval set -- "$args"

    local version="latest"
    local mode=""

    while true; do
        case "$1" in
            -d|--download)
                mode="download"
                shift
                ;;

            -l|--list)
                mode="list"
                shift
                ;;

            -v|--version)
                version="$2"
                shift
                shift
                ;;

            --)
                shift
                break
                ;;

            *)
                die "${usage}"
                ;;
        esac
    done

    case "${mode}" in
        list)
            list-tarballs
            ;;

        download)
            download-tarball "${version}"
            ;;

        *)
            show-usage
            ;;
    esac
}

if [[ -z "${ROOTDIR}" || -z "${RUSTDIR}" ]]; then
    die "Source build/setup.sh first"
fi

main "$@"
