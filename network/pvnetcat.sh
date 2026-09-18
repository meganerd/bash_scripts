#!/bin/bash
# pvnetcat.sh - Send files (or stdin) to a remote host with pv progress bar and netcat
#
# Wraps: pv -s SIZE file | nc -N host port
#
# Usage:
#   pvnetcat.sh HOST PORT FILE [FILE...]
#   cat file | pvnetcat.sh HOST PORT

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 HOST PORT [FILE...]

Send FILE(s) or stdin to HOST:PORT with a pv progress bar over netcat.

When sending multiple files, each is sent as a separate connection with its own
progress bar. The receiver must be listening and re-accepting for each file.

Examples:
  $0 192.168.1.50 5555 large_file.zip
  $0 192.168.1.50 5555 file1.tar.gz file2.tar.gz
  cat backup.tar.gz | $0 192.168.1.50 5555

Receiver (on the other end):
  nc -l -p 5555 > received_file.zip
EOF
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

HOST="$1"
PORT="$2"
shift 2

send_stdin() {
    pv | nc -N "$HOST" "$PORT"
}

send_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "Error: '$file' not found or not a regular file." >&2
        exit 1
    fi
    local size
    size=$(stat -c %s "$file" 2>/dev/null || du -sb "$file" | awk '{print $1}')
    pv -s "$size" "$file" | nc -N "$HOST" "$PORT"
}

if [ $# -eq 0 ]; then
    send_stdin
else
    for file in "$@"; do
        send_file "$file"
    done
fi
