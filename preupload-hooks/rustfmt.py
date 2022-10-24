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
    parser.add_argument("--rustfmt_path",
                        default="rustfmt",
                        help="The path to the rustfmt binary.")
    parser.add_argument('files',
                        type=str,
                        nargs='*',
                        help='If specified, only consider rustfmt in '
                        'these files.')
    return parser


def main(argv):
    """The main entry."""
    parser = get_parser()
    opts = parser.parse_args(argv)

    # Check and set rustfmt path in case `source build/setup.sh` is not run in
    # the shell session. In repo preupload, the path should be set in
    # PREUPLOAD.cfg.
    if opts.rustfmt_path != "rustfmt":
        # Add rustfmt path to system PATH and set up RUSTUP_HOME at one level up
        # rustfmt has to have both variables set up to work properly.
        path = os.path.realpath(opts.rustfmt_path + "/..")
        os.environ["PATH"] = path + ":" + os.getenv("PATH")
        os.environ["RUSTUP_HOME"] = path + "/.."

    # Only process .rs files
    file_list = [f for f in opts.files if f.endswith("rs")]
    if not file_list:
        sys.exit(0)

    nightly_flag = os.getenv("CANTRIP_RUST_VERSION") if os.getenv(
        "CANTRIP_RUST_VERSION") else "nightly-2021-11-05"

    cmd = [opts.rustfmt_path, f"+{nightly_flag}", "--check", "--color", "never"]

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
