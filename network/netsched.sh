#!/bin/bash
# Version = Dev_Non_Functional

ShowUsage()
{
printf "This script requires an interface .\n
-i	-- Interface to use.\n
-l	-- CoDel limit option (defaults to 300).\n
-f	-- Codel flow count.\n
-s 	-- Max send rate (in kbps).\n
-r 	-- Max receive rate (in kbps).\n
-h	-- Help (this text).\n

For example: netsched.sh -i eth0 -f 20480 -l 600 \n
"
}

# Default variable values
LimitNum=300
FlowNum=20480
InterfaceDev=wlan0

# Process arguments
while getopts "i:f:l:s:r:h" opt ; do
	case "$opt" in

	  i) iflag=1
	     InterfaceDev="$OPTARG" ;;
	  f) fflag=1
	     FlowNum=$OPTARG ;;
	  l) lflag=1
	     LimitNum=$OPTARG ;;
	  s) sflag=1
	      SendRate=$OPTARG ;;
	  r) rflag=1
	      ReceiveRate=$OPTARG ;;
	    
	  h) ShowUsage;;
	  :) ShowUsage;;
	esac
 
done

# Define the rest of the funtions.

ClearExistingQueue()
{
echo "removing shaping rules:"
# clean existing down- and uplink qdiscs, hide errors
tc qdisc del dev $InterfaceDev root
tc qdisc del dev $InterfaceDev ingress 
echo "complete"
}

SetQueue()
{
tc qdisc add dev $InterfaceDev root fq_codel target 3ms interval 40ms limit $LimitNum flows $FlowNum noecn quantum 1514
}