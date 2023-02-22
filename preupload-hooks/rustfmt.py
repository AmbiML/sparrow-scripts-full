#!/usr/bin/env python3
# Copyright 2022 Google LLC
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
"""Wrapper to run  rustfmt for repo preupload."""

import argparse
import os
import subprocess
import sys


def get_parser():
    """Return a command line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files',
                        type=str,
                        nargs='*',
                        help='If specified, only consider rustfmt in '
                        'these files.')
    return parser


def main(argv):
    """The main entry."""
    if not os.getenv("ROOTDIR"):
        print("source build/setup.sh first")
        sys.exit(1)

    parser = get_parser()
    opts = parser.parse_args(argv)

    # Only process .rs files
    file_list = [f for f in opts.files if f.endswith("rs")]
    if not file_list:
        sys.exit(0)

    nightly_flag = os.getenv("CANTRIP_RUST_VERSION")

    cmd = ["rustfmt", f"+{nightly_flag}", "--check", "--color", "never"]

    for f in file_list:
        cmd.append(f)

    # Run rustfmt on all the .rs files in the file list. `--check` flag
    # prints out the formatting error and return with exit(1).
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"rustfmt check failed\ncmd: {cmd}\nexit code {e.returncode}")
        sys.exit(e.returncode)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main(sys.argv[1:])
