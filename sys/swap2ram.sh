#!/bin/sh
# Script from https://help.ubuntu.com/community/SwapFaq#What_is_swappiness_and_how_do_I_change_it.3F

mem=$(free  | awk '/Mem:/ {print $4}')
swap=$(free | awk '/Swap:/ {print $3}')

if [ $mem -lt $swap ]; then
    echo "ERROR: not enough RAM to write swap back, nothing done" >&2
    exit 1
fi

swapoff -a && 
swapon -a
