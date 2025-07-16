#!/bin/bash
#
# This script requires a URL as input.  If no input is given, then display the 
# following message.

USAGE="This script requires a youtube URL as an argument."

if [ "$#" = "0" ]; then
        echo "$USAGE"
        exit 1
fi

# Testing to see if the youtube-dl program is installed and available via the
# default path.
if ! which youtube-dl &> /dev/null; then
    echo "youtube-dl utility is not available, please install it"
    exit 1
fi

# Grabbing the best available quality level for this video.
bestlevel=$(youtube-dl --default-search auto -F "$1" |grep best )

echo "Selecting the following quality level."
echo "$bestlevel"

# Selecting the numerical quality value that youtube-dl will use to download the video. 
qualitylevel=$(echo "$bestlevel" |cut -f 1 -d " ")

echo "Beginning download of video into the following directory: $(pwd)"

# Downloading the video into the current directory.
youtube-dl --default-search auto -f "$qualitylevel" "$1"
