#!/bin/bash
if [ "$1" != "" ]; then
        dir_to_check="$1"
else
        dir_to_check="."
fi
du -Pachx $dir_to_check --max-depth=1 |sort -h

