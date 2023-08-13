#! /bin/bash
# Copyright 2023 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Wrapper to run buildifier for repo preupload.
# Usage: run_buildifier.sh ${PREUPLOAD_COMMIT}
# The script fails if buildifier produces any output.

set -e

function buildifier_info_exit(){
  cat << EOM
No buildifier found. Please run

${ROOTDIR}/scripts/install-buildifier.sh
EOM
  exit 1
}

if [[ -z ${ROOTDIR} ]]; then
  echo "source build/setup.sh first"
  exit 1
fi

test -f "${ROOTDIR}/cache/buildifier/buildifier" || buildifier_info_exit

COMMIT="$1"

declare -a included_files_patterns=(
  "/BUILD$"
  "\.bazel$"
  "/WORKSPACE$"
  "\.bzl$"
)

declare -a excluded_files_patterns=(
  "/third_party/"
  "^third_party/"
)

# Join on |
included_files_pattern="$(IFS="|" ; echo "${included_files_patterns[*]?}")"
excluded_files_pattern="$(IFS="|" ; echo "${excluded_files_patterns[*]?}")"

# Create the buildifier file list.
readarray -t files < <(\
  (git diff --name-only --diff-filter=d "${COMMIT}^!" || kill $$) \
    | grep -E "${included_files_pattern?}" \
    | grep -v -E "${excluded_files_pattern?}")

if (( ${#files[@]} == 0 )); then
  exit 0
fi

# Run buildifier formatter and linter. The diff is compared with git-diff.
"${CACHE}/buildifier/buildifier" "${files[@]}" || (echo "buildifier error" && exit 1)

git diff --exit-code || (echo """
Please amend the commit with:

${CACHE}/buildifier/buildifier ${files[@]}
""" && \
  git reset --hard && exit 1)
