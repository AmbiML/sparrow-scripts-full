#!/usr/bin/env python3

import base64
import cmd
import curses.ascii
import select
import socket
import sys
import time

from elftools.elf.elffile import ELFFile


class BootromShell(cmd.Cmd):
    intro = "Welcome to Bootrom Shell"
    prompt = "BOOTROM> "
    socket = None
    poller = None
    pty_in = None
    pty_out = None
    connected = False
    use_pty = False

    ############################################################################
    # Network stuff here

    # Try and connect to {host_addr} once per second for {max_retry} seconds
    def connect(self, host_name, host_addr, max_retry):
        if self.use_pty:
            # pylint: disable=R1732
            self.pty_in = open("/tmp/uart", "rb", buffering=0)
            self.pty_out = open("/tmp/uart", "wb", buffering=0)
            self.poller = select.poll()
            self.poller.register(self.pty_in, select.POLLIN)
            return True
        if self.socket is None:
            print("Opening socket")
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        print(f"Connecting to {host_name}", end="")
        for _ in range(max_retry):
            try:
                self.socket.connect(host_addr)
                self.connected = True
                self.poller = select.poll()
                self.poller.register(self.socket, select.POLLIN)
                print("Connected!")
                return True
            except ConnectionError:
                print(".", end="")
                sys.stdout.flush()
                time.sleep(1)
        print("Connection timed out!")
        return False

    def disconnect(self):
        if self.pty_in is not None:
            print("Closing pty_in")
            self.pty_in.close()
        if self.pty_out is not None:
            print("Closing pty_in")
            self.pty_out.close()
        if self.socket is not None:
            print("Closing socket")
            self.socket.close()
        self.connected = False
        self.pty_in = None
        self.pty_out = None
        self.socket = None
        self.poller = None

    def getpeername(self):
        if self.use_pty:
            return "/tmp/uart"
        return self.socket.getpeername()

    def send(self, data):
        if self.use_pty:
            self.pty_out.write(data)
            self.pty_out.flush()
        else:
            self.socket.send(data)

    def recv(self, size):
        if self.use_pty:
            print(self.pty_in)
            result = self.pty_in.read(size)
            return result
        result = self.socket.recv(size)
        if len(result) == 0:
            self.disconnect()
        return result

    def poll(self, timeout):
        if self.connected:
            poll_result = self.poller.poll(timeout)
            return len(poll_result) != 0
        return False

    ############################################################################

    # Dumps incoming packet to the console, returns true if it contained a sync
    # symbol
    def print_packet(self, echo=False):
        saw_sync = False
        received = self.recv(4096)
        for c in received:
            if c == curses.ascii.ETX:
                saw_sync = True
            elif echo:
                sys.stdout.write(chr(c))
        sys.stdout.flush()
        return saw_sync

    # Waits until we see a packet containing a sync symbol or the line has been
    # idle for {timeout}
    def wait_for_sync(self, timeout, echo=True):
        while True:
            if not self.connected:
                return False
            if self.poll(timeout):
                if self.print_packet(echo):
                    return True
            else:
                return False

    # Collects bytes in a string until we see a sync symbol or we timeout
    def wait_for_response(self, timeout):
        result = bytearray()
        while True:
            if self.poll(timeout):
                received = self.recv(1)
                if received[0] == curses.ascii.ETX:
                    return result
                result.append(received[0])
            else:
                print("Timeout while waiting for command response")
                return b""

    # Waits until the line has been idle for {timeout}
    def wait_for_idle(self, timeout, echo=True):
        while True:
            if self.poll(timeout):
                self.print_packet(echo)
            else:
                break

    def run_command(self, line):
        if self.connected:
            self.send((line + "\n").encode())
            self.wait_for_sync(100000)
        else:
            print("Not connected!")

    ############################################################################

    def load_blob_at(self, blob, address):
        chunks = [blob[i:i + 65536] for i in range(0, len(blob), 65536)]
        for chunk in chunks:
            self.send(f"write {hex(address)}\n".encode())
            self.wait_for_response(100000)
            self.send(base64.b64encode(chunk))
            self.send("\n".encode())
            self.wait_for_sync(100000)
            address = address + 65536

    def load_file_at(self, filename, address):
        try:
            with open(filename, "rb") as file:
                print("file opened")
                blob = file.read()
                print("blob read")
                self.load_blob_at(blob, address)
        except OSError as e:
            print(f"Could not load {filename}")
            print(f"Exception {e}   ")

    def load_elf(self, filename):
        try:
            # pylint: disable=R1732
            elf_file = ELFFile(open(filename, "rb"))
            print(f"Entry point at {hex(elf_file.header.e_entry)}")
            return elf_file
        except OSError:
            print(f"Could not open '{filename}' as an ELF file")
            return None

    def upload_elf(self, elf_file):
        if elf_file is None:
            print("No elf file")
            return False
        for segment in elf_file.iter_segments():
            header = segment.header
            if header.p_type == "PT_LOAD":
                start = header.p_paddr
                size = header.p_filesz
                end = start + size
                print(
                    f"Loading seg: {hex(start)}:{hex(end)} ({size} bytes)...")
                sys.stdout.flush()
                self.load_blob_at(segment.data(), start)

        return True

    ############################################################################
    # cmd.Cmd callbacks here

    def do_connect(self, _=""):
        """Connects to the Renode server, localhost@31415 by default."""
        host_name = "Renode"
        host_addr = ("localhost", 31415)
        max_retry = 60

        if self.connect(host_name, host_addr, max_retry):
            print(f"Connected to {host_name} @ {self.getpeername()}")
        else:
            print(
                f"Failed to connect to {host_name} after {max_retry} seconds")
            self.disconnect()
            return

        # Ping the server with a newline once per second until we see a sync
        # symbol and the line goes idle for 100 msec.
        print("Waiting for prompt...")
        for _ in range(180):
            if not self.connected:
                break
            self.send("\n".encode())
            if self.wait_for_sync(1000):
                # Sync seen, turn remote echo off and mute the ack
                self.send("echo off\n".encode())
                self.wait_for_idle(100, False)
                return

        print("Did not see command prompt from server")
        self.disconnect()
        return

    def do_disconnect(self, _=""):
        """Disconnect from the Renode server"""
        self.disconnect()

    def do_reconnect(self, _=""):
        """Reconnect to the Renode server"""
        self.do_disconnect()
        self.do_connect()

    ##----------------------------------------

    def do_boot_elf(self, line=""):
        """Load local ELF file to remote device and boot it"""
        try:
            e = self.load_elf(line)
            if e is None:
                print(f"Could not open '{line}' as an ELF file")
                return False

            self.upload_elf(e)
            self.send(f"boot {hex(e.header.e_entry)}\n".encode())
            self.wait_for_sync(100000)
        except OSError:
            print(f"Failed to boot {line}")
        return True

    def do_load_elf(self, line=""):
        """Load local ELF file to remote device"""
        e = self.load_elf(line)
        if e is None:
            print(f"Could not open '{line}' as an ELF file")
            return False

        self.upload_elf(e)
        return False

    def do_load_file_at(self, line):
        """Uploads a binary file to a fixed address"""
        args = line.split()
        self.load_file_at(args[0], int(args[1], 16))

    def do_load_xflash(self, line):
        """Uploads a binary file to external flash"""
        self.load_file_at(line, "0x44000000")

    def do_boot_sec(self, line):
        """Boots an app on SEC at the given entry point.
        This will kill the active bootrom console session."""
        self.send(f"boot {line}\n".encode())
        self.wait_for_idle(100)

    def do_boot_smc(self, line):
        """Boots an app on SMC at the given entry point.
        If entry == 0, will stop SMC."""
        self.send(f"poked 0x54020000 {line}")
        self.wait_for_idle(100)

    ##----------------------------------------

    def do_help(self, arg=""):
        """Displays local and remote commands"""
        super().do_help(arg)
        if not arg:
            print("Remote commands")
            print("================")
            print()
            self.run_command("help")

    def do_exit(self, _=""):
        """Exits BootromShell"""
        self.disconnect()
        return True

    ##----------------------------------------

    def default(self, line):
        self.run_command(line)

    def emptyline(self):
        pass

    ##----------------------------------------

    # Command completeion callback (todo)
    # pylint: disable=W0221
    def completenames(self, text, line, begidx, endidx):
        result = super().completenames(text, line, begidx, endidx)
        return result

    # Argument completion callback (todo)
    # pylint: disable=W0221
    def completedefault(self, text, line, begidx, endidx):
        result = super().completedefault(text, line, begidx, endidx)
        return result


################################################################################

if __name__ == '__main__':
    print("<<shell starting>>")
    shell = BootromShell()
    shell.do_connect()
    shell.cmdloop()
    print("<<shell closed>>")
