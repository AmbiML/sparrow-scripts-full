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

"""
quick_sim.py is a tool to quickly launch simulations

It does a fuzzy search using fzf on the scripts directory
and then executes them using renode.
"""
import argparse
import logging
import os
import subprocess
from glob import iglob

from pyfzf.pyfzf import FzfPrompt

parser = argparse.ArgumentParser(
    description="Start renode simulation.")

parser.add_argument('--script', dest='script_file',
                    help='script file to run within renode',
                    default="")

parser.add_argument('--prompt-elf', dest='prompt_elf',
                    help='prompt for elf',
                    default=False, action="store_true")

parser.add_argument('--elf', dest='elf_file',
                    help='elf to run within renode',
                    default="")

parser.add_argument('--start-sim', dest='start_sim',
                    help='start the simulator',
                    default=False, action="store_true")

parser.add_argument("-v", "--verbose", help="increase output verbosity",
                    action="store_true")

args = parser.parse_args()
env = os.environ.copy()

if args.verbose:
    logging.basicConfig(level=logging.DEBUG)


def prompt_for_file(search_paths):
    """ Prompt user for a file using a list of search paths."""

    paths = []

    for scripts  in [iglob(p, recursive=True) for p in search_paths]:
        paths += scripts

    fzf = FzfPrompt()
    script_file = fzf.prompt(paths)[0]
    return script_file


def launch_renode(script_file, elf_file, start=False):
    """ Given a script execute it in our environment using renode"""

    cmd = ["mono",
            "%s/host/renode/Renode.exe" % env['OUT']]

    if not elf_file == "":
        cmd.append(r'-e"\$bin=@%s"' % elf_file)

    cmd.append('-e"i @%s"' % script_file)
    if start:
        cmd.append('-e"start"')

    cmd.append("--disable-xwt")
    cmd = " ".join(cmd)
    logging.info("Executing command: %s", cmd)

    try:
        proc = subprocess.Popen(cmd, env=env, shell=True)
        while True:
            pass
    except KeyboardInterrupt:
        proc.wait()
        logging.info("Exiting simulation")

def main():
    """ Main entry point for quick_sim.py"""

    logging.debug("Change directory to ROOTDIR")
    if "ROOTDIR" in env:
        os.chdir(env['ROOTDIR'])
        logging.debug("Current directory set to %s", os.path.abspath(os.curdir))
    else:
        parser.error("Please source setup script: source build/setup.sh")

    logging.info("Looking for simulation scripts to run...")

    search_path_names = ["sim/config/**/*.resc", "out/renode_configs/*.resc"]

    script_file = args.script_file
    if script_file == "":
        script_file = prompt_for_file(search_path_names)

    logging.debug("Selected %s", script_file)
    if not os.path.exists(script_file):
        parser.error("Selected script does not exist.")

    elf_file = args.elf_file
    if args.prompt_elf:
        search_path_names = ["out/**/*.elf"]
        if elf_file == "":
            elf_file = prompt_for_file(search_path_names)

        logging.debug("Selected elf %s", elf_file)
        if not os.path.exists(elf_file):
            parser.error("Selected elf does not exits.")

    launch_renode(script_file, elf_file, args.start_sim)

if __name__ == "__main__":
    main()
