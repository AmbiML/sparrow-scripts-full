#!/usr/bin/env python3
"""Download IREE host compiler from the snapshot release."""

import os
import sys
import tarfile
import argparse
import requests
import wget

from pathlib import Path


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
        print("%s is not found" % (keywords[0]))
        sys.exit(1)

    print("\nDownload %s from %s\n" % (artifact_name, download_url))
    if not os.path.isdir(out_dir):
        os.mkdir(out_dir)
    out_file = os.path.join(out_dir, artifact_name)
    wget.download(download_url, out=out_file)
    return out_file


def main():
    """ Download IREE host compiler from the snapshot release."""
    iree_compiler_dir = os.getenv("IREE_COMPILER_DIR")
    if not iree_compiler_dir:
        print("Please run 'source build/setup.sh' first")
        sys.exit(1)
    iree_compiler_dir = Path(iree_compiler_dir)

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
        "--depth", action="store", default="60",
        help=("Depth of the release history to search the snapshot for "
              "(max 100). (default: 60)")
    )
    args = parser.parse_args()
    r = requests.get(("%s?per_page=%s" % (args.release_url, args.depth)),
                     auth=('user', 'pass'))

    if r.status_code != 200:
        print("Not getting the right snapshot information. Status code: %d",
              r.status_code)
        sys.exit(1)

    tag_found = False
    snapshot = None
    if args.tag_name:
        for x in r.json():
            if x["tag_name"] == args.tag_name:
                tag_found = True
                snapshot = x
                break
    else:
        tag_found = True
        snapshot = r.json()[0]

    if not tag_found:
        print("!!!!!IREE snapshot can't be found with tag %s, please try a "
              "different tag!!!!!" % args.tag_name)
        sys.exit(1)

    tag_name = snapshot["tag_name"]
    commit_sha = snapshot["target_commitish"]

    print("Snapshot: %s" % tag_name)

    tag_file = iree_compiler_dir / "tag"

    # Check the tag of the existing download.
    tag_match = False
    if os.path.isfile(tag_file):
        with open(tag_file, 'r') as f:
            for line in f:
                if tag_name == line.replace("\n", ""):
                    tag_match = True
                    break

    if tag_match:
        print("IREE compiler is up-to-date")
        sys.exit(0)

    tmp_dir = Path(os.getenv("OUT")) / "tmp"
    whl_file = download_artifact(snapshot["assets"],
                                 ["iree_tools_tflite", "linux", "x86_64.whl"],
                                 tmp_dir)
    tar_file = download_artifact(
        snapshot["assets"], ["linux-x86_64.tar"], tmp_dir)

    # Install IREE TFLite tool
    cmd = ("pip3 install %s --no-cache-dir" % whl_file)
    os.system(cmd)

    # Extract the tarball to ${iree_compiler_dir}/install
    install_dir = iree_compiler_dir / "install"
    if not install_dir:
        os.mkdir(install_dir)

    tar = tarfile.open(tar_file)
    tar.extractall(path=install_dir)
    tar.close()

    os.remove(tar_file)
    os.remove(whl_file)
    print("\nIREE compiler is installed")

    # Add tag file for future checks
    with open(tag_file, "w") as f:
        f.write("%s\ncommit_sha: %s\n" % (tag_name, commit_sha))


if __name__ == "__main__":
    main()
