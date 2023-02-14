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
# Install buildifier as bazel formatter

if [[ -z ${ROOTDIR} ]]; then
  echo "source build/setup.sh first"
  exit 1
fi

if [[ -f "${CACHE}/buildifier/buildifier" ]]; then
  echo "buildifier installed"
  exit 0
fi

mkdir -p "${CACHE}/buildifier"

wget "https://storage.googleapis.com/sparrow-public-artifacts/buildifier_4.0.1" -O "${CACHE}/buildifier/buildifier"

chmod +x "${CACHE}/buildifier/buildifier"
