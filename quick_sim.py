#!/usr/bin/env python3
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

    for scripts  in [iglob(p) for p in search_paths]:
        paths += scripts

    fzf = FzfPrompt()
    script_file = fzf.prompt(paths)[0]
    return script_file


def launch_renode(script_file, start=False):
    """ Given a script execute it in our environment using renode"""

    cmd = ["mono",
            "%s/host/renode/Renode.exe" % env['OUT'],
            '-e"i @%s"' % script_file]
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

    search_path_names = ["sim/config/**/*.resc", "sim/config/*.resc"]

    script_file = args.script_file
    if script_file == "":
        script_file = prompt_for_file(search_path_names)

    logging.debug("Selected %s", script_file)
    if not os.path.exists(script_file):
        parser.error("Selected script does not exist.")

    launch_renode(script_file, args.start_sim)

if __name__ == "__main__":
    main()
