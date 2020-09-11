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
    bison
    build-essential
    ccache
    clang
    cmake
    cmake-curses-gui
    curl
    device-tree-compiler
    doxygen
    flex
    gdb
    git
    gtk-sharp2
    haskell-stack
    libcanberra-gtk-module
    libclang-dev
    libcunit1-dev
    libc6-dev gcc
    libgtk2.0-0
    libsqlite3-dev
    libssl-dev
    libwww-perl
    libxml2-dev
    libxml2-utils
    libxslt-dev
    libzmq5
    mlton
    mono-complete
    ncurses-dev
    ninja-build
    protobuf-compiler
    python-dev
    python-protobuf
    python3
    python3-dev
    python3-pip
    qemu-system
    rsync
    texinfo
    texlive-bibtex-extra
    texlive-fonts-recommended
    texlive-latex-extra
    texlive-metapost
    u-boot-tools
    uml-utilities
    policykit-1
    screen
)

PYTHON_PACKAGES=(
    camkes-deps
    sel4-deps
    setuptools
    robotframework==3.1
    netifaces
    requests
    psutil
    pyyaml
)

function die {
    [[ ! -z "$@" ]] && echo "$@"
    exit 1
}

function try {
    "$@" || die
}

function sudo_try {
    echo "sudo $@"
    sudo "$@" || die
}

function try_install_apt_packages {
    sudo_try apt-get update
    sudo_try apt-get install -y "${APT_PACKAGES[@]}"
}

function try_install_python_packages {
    local package

    if ! pip >/dev/null && ! apt-get install python-pip; then
        echo
        echo "Seems like you're on a newer distro that doesn't include pip for python2"
        echo "Please run the following and re-run the prereqs target:"
        echo
        echo "  curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py"
        echo "  chmod +x get-pip.py"
        echo "  ./get-pip.py"
        die
    fi

    for package in "${PYTHON_PACKAGES[@]}"; do
        try pip install "${package}"
        try pip3 install "${package}"
    done
}

echo "Installing apt package dependencies..."
try_install_apt_packages

echo "Installing python package dependencies..."
try_install_python_packages

echo "Installation complete."
