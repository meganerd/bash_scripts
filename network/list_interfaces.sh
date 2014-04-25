#!/bin/bash
# This lists attached network devices, while excluding the loopback (lo) device.
for i in `cat /proc/net/dev | grep ':' | cut -d ':' -f 1`; 
	do  ifname=`echo $i | tr -d ' '`  echo "$i" |grep -v lo;
	done
