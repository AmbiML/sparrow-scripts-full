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

# Install prebuilt verible linter/formatter

function clean {
  if [[ ! -f "${PREINSTALL_DIR}/${VERIBLE_TARBALL}" ]]; then
    rm "${DOWNLOAD_DIR}/${VERIBLE_TARBALL}"
    rmdir "${DOWNLOAD_DIR}"
  fi
}

if [[ -z "${ROOTDIR}" ]]; then
  echo "Source build/setup.sh first"
  exit 1
fi

# TODO Check where this full name belongs (e.g. build folder?)
VERIBLE_TARBALL="verible.tar.gz"

trap clean EXIT

# Used by the CI sparrow docker image
PREINSTALL_DIR=/usr/src

if [[ -f "${PREINSTALL_DIR}/${VERIBLE_TARBALL}" ]]; then
  echo "${VERIBLE_TARBALL} stored in the machine at ${PREINSTALL_DIR}"
  DOWNLOAD_DIR="${PREINSTALL_DIR}"
else
  echo "Download ${VERIBLE_TARBALL} from GCS..."
  DOWNLOAD_URL="https://storage.googleapis.com/sparrow-public-artifacts/verible.tar.gz"
  DOWNLOAD_DIR="${OUT}/tmp/verible"

  if [[ ! -d "${DOWNLOAD_DIR}" ]]; then
    mkdir -p "${DOWNLOAD_DIR}"
  fi

  wget -P "${DOWNLOAD_DIR}" "${DOWNLOAD_URL}"
fi

if [[ ! -d "${OUT}/host/verible" ]]; then
  mkdir -p "${OUT}/host/verible"
fi

tar -C "${OUT}/host/verible" --strip-components 1 -xf "${DOWNLOAD_DIR}/${VERIBLE_TARBALL}"

if [[ -d "${OUT}/host/verible/bin" ]]; then
  echo "Verible binaries now available in ${OUT}/host/verible/bin"
fi

