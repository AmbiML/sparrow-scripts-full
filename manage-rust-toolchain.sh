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

# Build a rust toolchain tarball for download use later.

PUBLIC_ARTIFACTS_PATH="gs://sparrow-public-artifacts"

function die {
    echo "$@" >/dev/stderr
    exit 1
}

function try {
    echo "$@"
    "$@" || die "Failed to execute '$@': exited with return code $?"
}

function show-usage {
    cat >/dev/stderr <<EOF
Usage: manage-rust-toolchain.sh [-c|-u|-p <date>]

Creates, uploads, and promotes Rust toolchain tarballs from toolchain installs
on local disk in cache/.

Options:
  -l | --list        List available rust tarballs.
  -c | --create      Create a new toolchain tarball and sha256sum from files in
                         cache/.
  -u | --upload      Upload the existing toolchain tarball to Google storage.
                         Note: requires the Google Cloud SDK to be installed and
                         logged in to function.
  -p <date> | --promote <date>
                     Promote the given date stamp tarball to latest.
EOF
    exit 1
}

function generate-tarball-name {
    local datestamp=$(date -I)
    echo "rust_toolchain_${datestamp}.tar.xz"
}

function create-tarball {
    if [[ ! -d "${RUSTDIR}" ]]; then
        die "No rust toolchain installed at ${RUSTDIR}. Please install it first, and try again."
    fi

    local tarball="$(generate-tarball-name)"

    if [[ -f "${ROOTDIR}/out/${tarball}" ]]; then
        die "Tarball ${tarball} already exists -- cowardly refusing to overwrite it."
    fi

    echo "Creating tarball in ${ROOTDIR}/out/${tarball}..."
    tar -C "${ROOTDIR}/cache" -c -f - rust_toolchain \
        |xz -T0 -9 \
        > "${ROOTDIR}/out/${tarball}"

    if [[ "$?" != 0 ]]; then
        rm -f "${ROOTDIR}/out/${tarball}"
        die "Couldn't create tarball."
    fi

    echo "Generating sha256sums..."
    (cd "${ROOTDIR}/out" && sha256sum "${tarball}") > "${ROOTDIR}/out/${tarball}.sha256sum"
}

function list-tarballs {
    echo "Available tarballs:"
    echo
    gsutil ls "${PUBLIC_ARTIFACTS_PATH}/rust_toolchain*.tar.xz"
}

function upload-tarball {
    local tarball="$(generate-tarball-name)"

    echo "Uploading tarball..."
    try gsutil cp "${ROOTDIR}/out/${tarball}" "${PUBLIC_ARTIFACTS_PATH}/${tarball}"
    try gsutil cp "${ROOTDIR}/out/${tarball}.sha256sum" "${PUBLIC_ARTIFACTS_PATH}/${tarball}.sha256sum"
}

function promote-tarball {
    local promote_date="$1"; shift

    echo "Promoting tarball rust_toolchain_${promote_date}.tar.xz to rust_toolchain_latest.tar.xz"
    try gsutil cp \
        "${PUBLIC_ARTIFACTS_PATH}/rust_toolchain_${promote_date}.tar.xz" \
        "${PUBLIC_ARTIFACTS_PATH}/rust_toolchain_latest.tar.xz"
    try gsutil cp \
        "${PUBLIC_ARTIFACTS_PATH}/rust_toolchain_${promote_date}.tar.xz.sha256sum" \
        "${PUBLIC_ARTIFACTS_PATH}/rust_toolchain_latest.tar.xz.sha256sum"
}

function main {
    local usage="Usage: manage-rust-toolchain.sh [-l|-c|-u|-p <date>]"
    local args=$(getopt -o h,l,c,u,p: --long help,list,create,upload,promote: \
                 -n manage-rust-toolchain.sh -- "$@")
    eval set -- "$args"

    local mode=""
    local promote_date=""

    while true; do
        case "$1" in
            -l|--list)
                mode="list"
                shift
                ;;

            -c|--create)
                mode="create-tarball"
                shift
                ;;

            -u|--upload)
                mode="upload"
                shift
                ;;

            -p|--promote)
                mode="promote"
                promote_date="$2"
                shift
                shift
                ;;

            -h|--help)
                show-usage
                ;;

            --)
                shift
                break
                ;;

            *)
                die "Unknown option '$1'; maybe try --help?"
                ;;
        esac
    done

    case "${mode}" in
        list)
            list-tarballs
            ;;

        create-tarball)
            create-tarball
            ;;

        upload)
            upload-tarball
            ;;

        promote)
            promote-tarball "${promote_date}"
            ;;

        *)
            show-usage
            ;;
    esac
}

if [[ "$EUID" == 0 ]]; then
    die "This script must NOT be run as root."
fi

if [[ -z "${ROOTDIR}" || -z "${RUSTDIR}" ]]; then
    die "Source build/setup.sh first"
fi

if ! hash gsutil 2>/dev/null; then
    die "This script requires the Google SDK to be installed."
fi

main "$@"
