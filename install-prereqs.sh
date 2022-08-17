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

PYTHON_REQUIREMENTS=""
APT_REQUIREMENTS=""

APT_PACKAGES=(
    asciidoctor
    bazel
    bazel-5.1.1
    bison
    build-essential
    ccache
    clang
    clang-format
    cmake
    cmake-curses-gui
    cpio
    curl
    device-tree-compiler
    doxygen
    flex
    fzf
    gdb
    git
    gtk-sharp2
    graphviz
    haskell-stack
    lcov
    libcanberra-gtk-module
    libclang-dev
    libcunit1-dev
    libc6-dev
    libtool
    llvm-11-tools
    gcc
    g++
    gcc-11
    g++-11
    libftdi1
    libftdi1-dev
    libfl2
    libfl-dev
    libglib2.0-dev
    libglib2.0-dev-bin
    libgtk2.0-0
    libpixman-1-dev
    libpython3-dev
    libsqlite3-dev
    libssl-dev
    libtinfo-dev
    libtinfo5
    libwww-perl
    libxml2-dev
    libxml2-utils
    libxslt-dev
    libzmq5
    lrzsz
    mono-complete
    ncurses-dev
    ninja-build
    perl
    protobuf-compiler
    pv
    python-is-python3
    python3-protobuf
    python3
    python3-dev
    python3-pip
    rsync
    srecord
    texinfo
    texlive-bibtex-extra
    texlive-fonts-recommended
    texlive-latex-extra
    texlive-metapost
    u-boot-tools
    uml-utilities
    policykit-1
    screen
    wget
    xxd
    zlib1g
    zlib1g-dev
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

    if [[ ! -z "${APT_REQUIREMENTS}" ]]; then
        sed 's/#.*//' "${APT_REQUIREMENTS}" | sudo_try xargs apt-get install -y
    fi
}

function try_install_python_packages {
    local package
    if [[ ! -z ${PYTHON_REQUIREMENTS} ]]; then
        PIP_INSTALL_ARGS=""
        for REQ_FILE in ${PYTHON_REQUIREMENTS} ; do
            PIP_INSTALL_ARGS="${PIP_INSTALL_ARGS} -r ${REQ_FILE}"
        done
        pip3 install ${PIP_INSTALL_ARGS}
    fi
}

function main {
    local usage="Usage: install-prereqs.sh [-p python-requirements.txt] [-a apt-requirements.txt]"
    local args=$(getopt -o hp:a: \
                        --long help,python:,apt: \
                        -n install-prereqs.sh -- "$@")
    eval set -- "$args"

    while true; do
        case "$1" in
            -h|--help)
                echo $usage
                return 1
                ;;

            -p|--python)
                PYTHON_REQUIREMENTS="$2"
                shift 2
                ;;

            -a|--apt)
                APT_REQUIREMENTS="$2"
                shift 2
                ;;

            --)
                shift
                break
                ;;
        esac
    done

    echo "Installing apt package dependencies..."
    try_install_apt_packages

    echo "Installing python package dependencies..."
    try_install_python_packages

    echo "Installation complete."
}

main "$@"
