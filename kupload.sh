#!/bin/bash
# ZMODEM upload to the Kata rz command over the pty simulating the UART

sz -O $1 < /tmp/term > /tmp/term
