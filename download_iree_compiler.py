#!/usr/bin/env python3
"""Download IREE host compiler from the snapshot release."""

import os
import sys
import tarfile
import requests
import wget

iree_compiler_dir = os.getenv("IREE_COMPILER_DIR")
if not iree_compiler_dir:
    print("Please run 'source build/setup.sh' first")
    sys.exit(-1)

r = requests.get(
    "https://api.github.com/repos/google/iree/releases?per_page=1", auth=(
        'user', 'pass'))

if r.status_code != 200:
    print("Not getting the right snapshot information. Status code: %d", r.status_code)
    sys.exit(-1)

snapshot = r.json()[0]

tag_name = snapshot["tag_name"]
commit_sha = snapshot["target_commitish"]

print("Latest snapshot: %s" % tag_name)

tag_file = os.path.join(iree_compiler_dir, "tag")

# Check the tag of the existing download.
TAG_MATCH = False
if os.path.isfile(tag_file):
    file = open(tag_file, "r")
    for line in file:
        if tag_name == line.replace("\n", ""):
            TAG_MATCH = True
            file.close()
            break
    file.close()

if TAG_MATCH:
    print("IREE compiler is up-to-date")
    sys.exit(0)

# Find the linux tarball and download it.
TAR_MATCH = False
for asset in snapshot["assets"]:
    download_url = asset["browser_download_url"]
    tar_name = asset["name"]
    if "linux-x86_64.tar" in tar_name:
        TAR_MATCH = True
        break

if not TAR_MATCH:
    print("linux-x86_64 tarball is not found")
    sys.exit(-1)

print("Download %s from %s" % (tar_name, download_url))

tmp_dir = os.path.join(os.getenv("OUT"), "tmp")

if not os.path.isdir(tmp_dir):
    os.mkdir(tmp_dir)

tar_file = os.path.join(tmp_dir, tar_name)
wget.download(download_url, out=tar_file)

# Extract the tarball to ${iree_compiler_dir}/install
install_dir = os.path.join(iree_compiler_dir, "install")
if not install_dir:
    os.mkdir(install_dir)

tar = tarfile.open(tar_file)
tar.extractall(path=install_dir)
tar.close()

os.remove(tar_file)
print("\nIREE compiler is installed")

# Add tag file for future checks
with open(tag_file, "w") as f:
    f.write("%s\ncommit_sha: %s\n" % (tag_name, commit_sha))
