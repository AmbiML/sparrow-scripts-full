#! /usr/bin/env python3
"""Download and install renode release package."""

import argparse
import os
import re
import sys
import time
import tarfile
import urllib

from pathlib import Path

import wget


def download_artifact(url, artifact_name, out_dir):
    """Download the artifact from url."""
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out_file = os.path.join(out_dir, artifact_name)
    download_url = os.path.join(url, artifact_name)
    num_retries = 3
    for i in range(num_retries + 1):
        try:
            wget.download(download_url, out=out_file)
            break
        except urllib.error.HTTPError as exception:
            if i == num_retries:
                raise
            print(f"{exception}\nDownload failed. Retrying...")
            time.sleep(5)
    return out_file


def strip_top_directory(tar):
    """Renode packages the release with a top directory. Need to strip it."""
    members = tar.getmembers()
    out_members = []
    for member in members[1:]:
        if member.path.startswith(members[0].name + "/"):
            member.path = os.path.join(
                *(member.name.split(os.path.sep)[1:]))
            out_members.append(member)

    tag = re.search("(.+?)_portable", members[0].name).group(1)
    return tag, out_members


def main():
    """Download and install renode release package."""
    pin_toolchains = os.getenv('PIN_TOOLCHAINS', '').lower().split(' ')
    if "renode" in pin_toolchains:
        print()
        print("****************************************************")
        print("*                                                  *")
        print("*  PIN_TOOLCHAINS includes renode! Skipping the    *")
        print("*  download of the latest Renode binaries.         *")
        print("*  PLEASE DON'T file bugs for Renode mis-behavior! *")
        print("*                                                  *")
        print("****************************************************")
        print()
        sys.exit(0)

    out_dir = os.getenv("OUT")
    if not out_dir:
        out_dir = "/tmp"

    parser = argparse.ArgumentParser(
        description="Download Renode from Antmicro releases")
    parser.add_argument(
        "--release_name", action="store", default="",
        help="Release to be downloaded. If not set, download the latest")
    parser.add_argument(
        "--release_url",
        action="store",
        default="https://dl.antmicro.com/projects/renode/builds/?C=M;O=D",
        help=("URL to check the IREE release."
              "(default: https://dl.antmicro.com/projects/renode/builds/)"))
    parser.add_argument(
        "--renode_dir", action="store", required=True,
        default="",
        help=("Renode installed directory")
    )

    args = parser.parse_args()

    with urllib.request.urlopen(args.release_url) as website:
        html_list = website.read().decode("utf-8")
    files = re.findall(r'href="(renode-.*git.*\.linux-portable\.tar\.gz)"',
                       html_list)

    release_found = False
    release_name = None
    if args.release_name:
        for file in files:
            if args.release_name in file:
                release_found = True
                release_name = re.search(
                    "(.+?).linux-portable.tar.gz", file).group(1)
                break
    else:
        # The latest release is the symlink of the second entry.
        release_found = True
        release_name = re.search(
            "(.+?).linux-portable.tar.gz", files[1]).group(1)

    if not release_found:
        print(f"!!!!!Renode can't be found with release {args.release_name}, "
              "please try a different release!!!!!")
        sys.exit(1)

    print(f"Release: {release_name}")
    commit_sha = re.search("git(.+?)$", release_name).group(1)

    renode_dir = Path(args.renode_dir)
    if not os.path.isdir(renode_dir):
        os.makedirs(renode_dir)
    tag_file = renode_dir / "tag"

    # Check the tag of the existing download.
    release_match = False
    built_from_src = False
    if os.path.isfile(tag_file):
        with open(tag_file, "r", encoding="utf-8") as file:
            for line in file:
                if "built_from_src" in line.replace("\n", ""):
                    built_from_src = True
                    break
                if commit_sha in line.replace("\n", ""):
                    release_match = True
                    break
    if built_from_src:
        print("Renode was built from the source. run `m renode_clean` if you "
              "want to download the nightly release.")
        sys.exit(0)
    if release_match:
        print("Renode is up-to-date")
        sys.exit(0)

    tmp_dir = Path(out_dir) / "tmp"
    artifact_name = release_name + ".linux-portable.tar.gz"
    tar_file = download_artifact(args.release_url, artifact_name, tmp_dir)

    # Extract the tarball
    with tarfile.open(tar_file) as tar:
        _, members = strip_top_directory(tar)
        tar.extractall(members=members, path=renode_dir)

    os.remove(tar_file)
    print("\nRenode is installed")

    # Add tag file for future checks
    with open(tag_file, "w", encoding="utf-8") as file:
        file.write(f"{release_name}\ncommit_sha: {commit_sha}\n")


if __name__ == "__main__":
    main()
