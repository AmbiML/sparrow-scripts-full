#!/bin/bash
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
# Wrapper to run ansible-lint for repo preupload.
# Usage: ansible-checks.sh path/to/ansible ${PREUPLOAD_COMMIT}
# The script fails if any of the checks exit with non-zero status.

set -e

ANSIBLE_PATH=$1
if ! command -v ansible-lint >/dev/null; then
  echo "Command ansible-lint not found. Install the ansible-lint package."
  exit 1
fi

# Run ansible checks. Just lint for now
ansible-lint $ANSIBLE_PATH
