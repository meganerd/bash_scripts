#!/bin/bash
# This lists attached network devices, while excluding the loopback (lo) device.
grep ':' /proc/net/dev | cut -d ':' -f 1 | while read -r i;
	do  ifname=$(echo "$i" | tr -d ' '); echo "$ifname" |grep -v lo;
	done
