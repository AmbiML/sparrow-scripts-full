#! /bin/sh
# Connect to the kata console shell
stty sane -echo -icanon; socat - /tmp/term,raw; stty sane
