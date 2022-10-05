#!/usr/bin/env python
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

import argparse
import IPython
import logging
import threading
import os
import socket
import subprocess
import sys
import telnetlib
import time

ENVIRON = os.environ.copy()

log = logging.getLogger()
log_handle = logging.StreamHandler()
log.addHandler(log_handle)
log.setLevel(logging.INFO)


parser = argparse.ArgumentParser(
    description="Start renode and connect to UART.")

parser.add_argument('--script', dest='script_file',
                    help='script file to run within renode',
                    default="")

parser.add_argument('-i', '--interactive', dest='interactive',
                    help='enable interactive mode', default=False,
                    action="store_true")

parser.add_argument('-u', '--uart', dest='connect_uart',
                    help='enable uart', default=False,
                    action="store_true")

parser.add_argument('--setup_uart', dest='setup_uart',
                    help='setup uart', default=False,
                    action="store_true")


parser.add_argument('-U', '--uart_name', dest='uart_name',
                    help='select uart', default="sysbus.uart")


class RenodeMonitor(object):
    def __init__(self, host="127.0.0.1", port=1234):
        self.host = host
        self.port = port
        self.tn = None


    def connect(self):
        self.tn = telnetlib.Telnet(host=self.host, port=self.port)
        self.recieve_all()

    def recieve_all(self):
        while True:
            reply = self.tn.read_until("\n", timeout=.1)
            if reply:
                log.info(reply)
            else:
                break

    def send_command(self, command):
        log.info("Send command: %s", command)
        cmd = "\n%s\n" % command
        self.tn.write(cmd)
        self.recieve_all()

    def start(self):
        self.send_command("start")

    def execute_script(self, script_path):
        self.send_command("include @%s" % script_path)

    def setup_uart(self, uart_name="sysbus.uart"):
        log.info("Setup the uart %s", uart_name)
        self.send_command('emulation CreateServerSocketTerminal 3456 "term"')
        self.send_command("connector Connect %s term" % uart_name)
        time.sleep(0.5)
        self.recieve_all()

    def quit(self):
        self.send_command("quit")


class RenodeThread(threading.Thread):
    def __init__(self, script=""):
        super(RenodeThread, self).__init__()
        self.script = script
        self.proc = None
        self.connect()
        self.monitor = RenodeMonitor()
        time.sleep(2.0)
        self.monitor.connect()
        if script:
            self.monitor.execute_script(script)

    def connect(self):
        cmd = ["mono",
               "%s/host/renode/Renode.exe" % ENVIRON['OUT'],
               "--disable-xwt"]
        log.info("Runnning renode command '%s'", " ".join(cmd))
        self.proc = subprocess.Popen(cmd, env=ENVIRON,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT)

    def run(self):
        while True:
            output = self.proc.stdout.readline()
            if output:
                log.info(output)
            if self.proc.poll() is not None:
                break
        log.info("Waiting on renode to exit.")
        self.proc.wait()
        log.info("Renode has exited.")

    def kill(self):
        if self.proc:
            if self.proc.returncode is None:
                self.proc.kill()


def main():
    args = parser.parse_args()
    print(args)
    renode = RenodeThread(args.script_file)
    renode.start()

    if args.connect_uart or args.setup_uart:
        renode.monitor.setup_uart(uart_name=args.uart_name)
        time.sleep(0.5)
        renode.monitor.start()

    if args.connect_uart:
        log.info("\n\nConnect to UART\n\n")
        tn = telnetlib.Telnet('localhost', 3456)
        tn.close()
        tn.open('localhost', 3456)
        try:
            tn.interact()
        except KeyboardInterrupt:
            renode.kill()

    if args.interactive:
        IPython.embed()
        renode.kill()

if __name__ == "__main__":
    main()
