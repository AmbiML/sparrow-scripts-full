#!/bin/bash
# ZMODEM upload to the Kata rz command over the pty simulating the UART
#
# sz is "send ZMODEM", while pv, "pipe viewer" is used for rate limiting.
#
# Severe rate limiting is needed to avoid the Renode UART simulation dropping
# bytes when the RX FIFO is full, since it doesn't provide "hardware" flow
# control.

sz -O $1 < /tmp/term | pv -L 150 > /tmp/term
