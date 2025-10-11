#!/bin/bash

# network/longurl.sh
usage() {
    echo "Usage: $0 URL"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

URL="$1"

# Use curl to follow redirects and capture the Location header
LONG_URL=$(curl -sLI "$URL" | grep ^Location: | tail -n 1 | cut -d' ' -f2-)

if [ -z "$LONG_URL" ]; then
    echo "This does not appear to be a short URL."
else
    # Remove the trailing newline and print the long URL
    echo "${LONG_URL%$'\r'}"
fi
