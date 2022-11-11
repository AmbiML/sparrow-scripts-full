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

# Manage RISC-V GCC/LLVM toolchains w.r.t Sparrow's GCS service.

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
Usage: manage-riscv-toolchain.sh [-c <toolchain>|-l|-u <tarball>|-p <tarball>]

Create, uploads, and promotes RISC-V GGC/LLVM toolchain tarballs from toolchain installs
on local disk in cache/.

Options:
  -l              | --list               List available RISC-V tarballs.
  -c <toolchain>  | --create <toolchain>
                      Create a new toolchain tarball and sha256sum from files in
                      cache/.
  -u <tarball>    | --upload <tarball>
                      Upload the existing toolchain tarball to Google storage.
                        Note: requires the Google Cloud SDK to be installed and
                        logged in to function.
  -p <tarball>    | --promote <tarball>
                      Promote the existing tarball in backup to public.
                        Note: requires the Google Cloud SDK to be installed and
                        logged in to function.
EOF
    exit 1
}

function generate-tarball-name {
    local toolchain=$1
    local datestamp=$(date +%Y-%m-%d)
    if [[ ${toolchain} == "toolchain" ]]; then
      echo "toolchain_${datestamp}.tar.gz"
    elif [[ ${toolchain} == "toolchain_iree_rv32imf" ]]; then
      echo "toolchain_iree_rv32_${datestamp}.tar.gz"
    else
      die "Unsupported toolchain ${toolchain}"
    fi
}

function create-tarball {
    local toolchain=$1; shift
    if [[ ! -d "${CACHE}/${toolchain}" ]]; then
        die "No toolchain installed at ${CACHE}/${toolchain}. Please install it first, and try again."
    fi

    local tarball="$(generate-tarball-name ${toolchain})"

    if [[ -f "${OUT}/${tarball}" ]]; then
        die "Tarball ${tarball} already exists -- cowardly refusing to overwrite it."
    fi

    mkdir -p "${OUT}"

    echo "Creating tarball in ${OUT}/${tarball}..."
    tar -C "${ROOTDIR}/cache" -czf "${OUT}/${tarball}" "${toolchain}"

    if [[ "$?" != 0 ]]; then
        die "Couldn't create tarball."
    fi

    echo "Generating sha256sums..."
    (cd "${OUT}" && sha256sum "${tarball}") > "${OUT}/${tarball}.sha256sum"

    if [[ "$?" != 0 ]]; then
        die "Couldn't create sha256sum checksum file."
    fi

    echo "Verifying sha256sum is valid..."
    (cd "${OUT}" && sha256sum -c "${tarball}.sha256sum")

    if [[ "$?" != 0 ]]; then
        die "Couldn't verify sha256sum!"
    fi
}

function list-tarballs {
    echo "Available tarballs:"
    echo
    gsutil ls "${PUBLIC_ARTIFACTS_PATH}/toolchain_backups/toolchain*.tar.gz"
}

function upload-tarball {
    local tarball=$1; shift

    echo "Uploading tarball ${tarball}..."
    try gsutil cp "${OUT}/${tarball}" \
        "${PUBLIC_ARTIFACTS_PATH}/toolchain_backups/${tarball}"
    try gsutil cp "${OUT}/${tarball}.sha256sum" \
        "${PUBLIC_ARTIFACTS_PATH}/toolchain_backups/${tarball}.sha256sum"
}

function promote-tarball {
    local promote_tarball="$1"
    local tarball_name=""
    echo "Removing old latest toolchain..."
    if [[ ${promote_tarball} == "toolchain_iree_rv32"* ]]; then
        tarball_name="toolchain_iree_rv32"
    elif [[ ${promote_tarball} == "toolchain"* ]]; then
        tarball_name="toolchain"
    fi

    try gsutil rm \
        "${PUBLIC_ARTIFACTS_PATH}/${tarball_name}.tar.gz"
    try gsutil rm \
        "${PUBLIC_ARTIFACTS_PATH}/${tarball_name}.tar.gz.sha256sum"

    echo "Promoting tarball ${promote_tarball} to ${tarball_name}.tar.gz"
    try gsutil cp \
        "${PUBLIC_ARTIFACTS_PATH}/toolchain_backups/${promote_tarball}" \
        "${PUBLIC_ARTIFACTS_PATH}/${tarball_name}.tar.gz"
    try gsutil cp \
        "${PUBLIC_ARTIFACTS_PATH}/toolchain_backups/${promote_tarball}.sha256sum" \
        "${PUBLIC_ARTIFACTS_PATH}/${tarball_name}.tar.gz.sha256sum"
}

function main {
    local usage="Usage: manage-rust-toolchain.sh [-l|-c <toolchain> |-u <date> |-p <tarball>]"
    local args=$(getopt -o h,l,c:,u:,p: --long help,list,create:,upload:,promote: \
                 -n manage-rust-toolchain.sh -- "$@")
    eval set -- "$args"

    local mode=""
    local toolchain=""
    local upload_tarball=""
    local promote_tarball=""

    while true; do
        case "$1" in
            -l|--list)
                mode="list"
                shift
                ;;

            -c|--create)
                mode="create-tarball"
                toolchain="$2"
                shift
                shift
                ;;

            -u|--upload)
                mode="upload"
                upload_tarball="$2"
                shift
                shift
                ;;

            -p|--promote)
                mode="promote"
                promote_tarball="$2"
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
            create-tarball "${toolchain}"
            ;;

        upload)
            upload-tarball "${upload_tarball}"
            ;;

        promote)
            promote-tarball "${promote_tarball}"
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
