#!/bin/bash
#
# Copyright 2020 Google LLC
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

APT_PACKAGES=(
    build-essential
    ccache
    clang
    cmake
    cmake-curses-gui
    curl
    device-tree-compiler
    doxygen
    gdb
    git
    haskell-stack
    libclang-dev
    libcunit1-dev
    libsqlite3-dev
    libssl-dev
    libwww-perl
    libxml2-dev
    libxml2-utils
    libxslt-dev
    mlton
    ncurses-dev
    ninja-build
    protobuf-compiler
    python-dev
    python-pip
    python-protobuf
    python3-dev
    python3-pip
    qemu-kvm
    rsync
    texlive-bibtex-extra
    texlive-fonts-recommended
    texlive-latex-extra
    texlive-metapost
    u-boot-tools
)

PYTHON_PACKAGES=(
    camkes-deps
    sel4-deps
    setuptools
)

function die {
    [[ ! -z "$@" ]] && echo "$@"
    exit 1
}

function try {
    "$@" || die
}

function try_install_apt_packages {
    try sudo apt-get update
    try sudo apt-get install -y "${APT_PACKAGES[@]}"
}

function try_install_python_packages {
    local package

    for package in "${PYTHON_PACKAGES[@]}"; do
        try sudo pip install "${package}"
        try sudo pip3 install "${package}"
    done
}

echo "Installing apt package dependencies..."
try_install_apt_packages

echo "Installing python package dependencies..."
try_install_python_packages

echo "Installation complete."
