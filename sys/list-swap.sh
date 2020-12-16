#!/bin/bash
# Based on https://www.cyberciti.biz/faq/linux-which-process-is-using-swap/
# 
# This script lists and sorts by size the processes with data currently in swap

# This section tests to see if we are running as root, if not, sudo is used automatically
if [[ $EUID -ne 0 ]]; then
USE_SUDO="/usr/bin/sudo"
else USE_SUDO=""
fi

$USE_SUDO for file in /proc/*/status ; do $USE_SUDO awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r | less