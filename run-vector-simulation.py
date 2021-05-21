#!/usr/bin/env python3

import argparse
import logging
import subprocess
import re

logger = logging.getLogger(__name__)


class SimulationFailedError(Exception):
    pass


def get_parser():
    parser = argparse.ArgumentParser()
    # TODO(julianmb): support multiple simulators(qemu, renode, spike, verilator)
    parser.add_argument(
        '--simulator',
        required=True,
        choices=['qemu', 'renode', 'spike', 'verilator'])
    parser.add_argument('--boot-elf-path', required=True)
    parser.add_argument('--vector-elf-path', required=True)
    parser.add_argument('--simulator-path')
    return parser


def main():
    args = get_parser().parse_args()
    if args.simulator == 'qemu':
        run_qemu_simulation(args)
    elif args.simulator == 'renode':
        raise NotImplementedError
    elif args.simulator == 'spike':
        raise NotImplementedError
    elif args.simulator == 'verilator':
        raise NotImplementedError
    logger.info('test passed')

def run_qemu_simulation(args):
    cmd = [args.simulator_path,
        '-display', 'none',
        '-cpu', 'rv32,x-v=true,vlen=512,vext_spec=v1.0',
        '-M', 'opentitan',
        '-kernel', args.vector_elf_path,
        '-bios', args.boot_elf_path,
        '--chardev', 'file,id=s1,path=/dev/stdout',
        '-serial', 'chardev:s1']
    proc = subprocess.Popen(
        cmd, bufsize=0,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)
    stdout = proc.stdout
    test_finished_pattern = r'test_status\.c.*(PASS|FAIL)'
    while line:= stdout.readline():
        line = str(line, encoding='utf8').strip()
        logger.debug('line = %s', line)
        if(re.search(test_finished_pattern, line)):
            logger.debug('test finished')
            break
    if 'PASS' not in line:
        raise SimulationFailedError


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO,
        format=' - '.join(['%(asctime)s', '%(funcName)s', '%(message)s']))
    main()
