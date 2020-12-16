#!/bin/bash
# Based on https://www.cyberciti.biz/faq/linux-which-process-is-using-swap/
# 
# This script lists and sorts by size the processes with data currently in swap

for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r | less