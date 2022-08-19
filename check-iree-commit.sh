#!/bin/bash
#
# Copyright 2021 Google LLC
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

# Check IREE runtime commit version to be consistent with the compiler.

IREE_SRC="$1"
IREE_COMPILER_DIR="$2"

if [[ $# -ne 2 ]]; then
  echo "Usage: check-iree-commit.sh <iree source dir> <iree compiler dir>"
  exit 1
fi

COMMIT=$(git -C "${IREE_SRC}" rev-parse HEAD)

# Check the source commit is the same as the one recorded in the compiler tag.
if grep -q "${COMMIT}" "${IREE_COMPILER_DIR}/tag"; then
  echo "Source code commit matches with the compiler."
else
  echo -e "!!!!Source code commit mismatches with the compiler.\n\
Please check the info at \"${IREE_COMPILER_DIR}/tag\" with\n\
\"${IREE_SRC}\" if you hit the compilation/runtime errors.!!!!"
fi
