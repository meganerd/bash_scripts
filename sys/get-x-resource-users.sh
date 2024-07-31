#!/usr/bin/env bash
# Script from https://unix.stackexchange.com/questions/250920/debugging-maximum-number-of-clients-reached-unable-to-open-display-0
sudo ss -x src "*/tmp/.X11-unix/*" | grep -Eo "[0-9]+\s*$" | while read port
do sudo ss -p -x | grep -w $port | grep -v X11-unix 
done | grep -Eo '".+"' | sort | uniq -c | sort -rn
