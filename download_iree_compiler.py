#!/usr/bin/env python3
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

"""Download IREE host compiler from the snapshot release."""

import errno
import os
import sys
import shutil
import subprocess
import tarfile
import time
import argparse
import urllib
from pathlib import Path
import requests
import wget


def download_artifact(assets, keywords, out_dir):
    """Download the artifact from the asset list based on the keyword."""
    # Find the linux tarball and download it.
    artifact_match = False
    for asset in assets:
        download_url = asset["browser_download_url"]
        artifact_name = asset["name"]
        if all(x in artifact_name for x in keywords):
            artifact_match = True
            break
    if not artifact_match:
        print(f"{keywords[0]} is not found")
        sys.exit(1)

    print(f"\nDownload {artifact_name} from {download_url}\n")
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out_file = os.path.join(out_dir, artifact_name)

    num_retries = 3
    for i in range(num_retries + 1):
        try:
            wget.download(download_url, out=out_file)
            break
        except (urllib.error.HTTPError, ConnectionError) as e:
            if i == num_retries:
                raise
            print(f"{e}\nDownload failed. Retrying...")
            time.sleep(5)
    return out_file


def main():
    """ Download IREE host compiler from the snapshot release."""
    pin_toolchains = os.getenv("PIN_TOOLCHAINS", '').lower().split(' ')
    if "iree" in pin_toolchains:
        print()
        print("****************************************************")
        print("*                                                  *")
        print("*  PIN_TOOLCHAINS includes iree! Skipping the      *")
        print("*  download of the latest IREE compiler binaries.  *")
        print("*  Please DO NOT file bugs for IREE mis-behavior!  *")
        print("*                                                  *")
        print("****************************************************")
        print()
        sys.exit(0)

    parser = argparse.ArgumentParser(
        description="Download IREE host compiler from snapshot releases")
    parser.add_argument(
        "--tag_name", action="store", default="",
        help="snapshot tag to download. If not set, download the latest")
    parser.add_argument(
        "--release_url", action="store",
        default="https://api.github.com/repos/google/iree/releases",
        help=("URL to check the IREE release."
              "(default: https://api.github.com/repos/google/iree/releases)")
    )
    parser.add_argument(
        "--iree_compiler_dir", action="store", required=True,
        default="",
        help=("IREE compiler installed directory")
    )
    args = parser.parse_args()

    # Check if the IREE runtime lib is in sync with the tag
    root_dir = os.getenv("ROOTDIR")
    cmd = ["git", "-C", f"{root_dir}/toolchain/iree", "rev-parse", "HEAD"]

    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
    except subprocess.CalledProcessError as e:
        print("Failed to check IREE runtime version")
        sys.exit(e.returncode)

    iree_runtime_commit = result.stdout.decode("utf-8")
    iree_compiler_dir = Path(args.iree_compiler_dir)
    tag_file = iree_compiler_dir / "tag"

    if os.path.isfile(tag_file):
        with open(tag_file, "r", encoding="utf-8") as file:
            for line in file:
                if iree_runtime_commit.replace("\n", "") in line:
                    print("Compiler version matches runtime. Skip download")
                    sys.exit(0)

    snapshot = None
    if args.tag_name:
        r = requests.get((f"{args.release_url}/tags/{args.tag_name}"),
                         auth=('user', 'pass'),
                         timeout=60)
        if r.status_code != 200:
            print(
                f"!!!!!IREE snapshot can't be found with tag {args.tag_name}, "
                "please try a different tag!!!!!")
            sys.exit(1)
        snapshot = r.json()
    else:
        r = requests.get(args.release_url, auth=('user', 'pass'), timeout=60)
        if r.status_code != 200:
            print("Not getting the right snapshot information. Status code: %d",
                  r.status_code)
            sys.exit(1)
        snapshot = r.json()[0]

    tag_name = snapshot["tag_name"]
    commit_sha = snapshot["target_commitish"]

    print(f"Snapshot: {tag_name}")

    tag_file = iree_compiler_dir / "tag"

    # Check the tag of the existing download.
    tag_match = False
    if os.path.isfile(tag_file):
        with open(tag_file, 'r', encoding="utf-8") as f:
            for line in f:
                if tag_name == line.replace("\n", ""):
                    tag_match = True
                    break

    if tag_match:
        print("IREE compiler is up-to-date")
        sys.exit(0)

    tmp_dir = Path(os.getenv("OUT")) / "tmp"
    whl_file = download_artifact(snapshot["assets"],
                                 ["iree_tools_tflite", ".whl"], tmp_dir)
    tar_file = download_artifact(
        snapshot["assets"], ["linux-x86_64.tar"], tmp_dir)

    # Install IREE TFLite tool
    cmd = (f"pip3 install --target={iree_compiler_dir} {whl_file} "
           "--upgrade --no-cache-dir")
    os.system(cmd)

    # Extract the tarball to ${iree_compiler_dir}/install
    install_dir = iree_compiler_dir / "install"
    if not install_dir:
        os.makedirs(install_dir)

    with tarfile.open(tar_file) as tar:
        tar.extractall(path=install_dir)

    try:
        shutil.copy2(f"{iree_compiler_dir}/bin/iree-import-tflite",
                     f"{install_dir}/bin/iree-import-tflite",
                     follow_symlinks=True)
    except OSError as e:
        if e.errno == errno.EEXIST:
            os.remove(f"{install_dir}/bin/iree-import-tflite")
            shutil.copy2(f"{iree_compiler_dir}/bin/iree-import-tflite",
                         f"{install_dir}/bin/iree-import-tflite",
                         follow_symlinks=True)

    os.remove(tar_file)
    os.remove(whl_file)
    print("\nIREE compiler is installed")

    # Add tag file for future checks
    with open(tag_file, "w", encoding="utf-8") as f:
        f.write(f"{tag_name}\ncommit_sha: {commit_sha}\n")


if __name__ == "__main__":
    main()
