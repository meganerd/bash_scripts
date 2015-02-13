#!/bin/bash
# Version = 0.1-alpha
# Seems to work, not well tested as yet.

ShowUsage()
{
printf "This script requires an interface .\n
-d 	-- Clears all existing queues on a given interface.\n
-i	-- Interface to use.\n
-l	-- CoDel limit option (defaults to 300).\n
-f	-- Codel flow count (defaults to 20480).\n
-v	-- Takes an interface as argument, displays existing queue(s).
-s 	-- Max send rate (in kbps) [UNUSED].\n
-r 	-- Max receive rate (in kbps) [UNUSED].\n
-h	-- Help (this text).\n

For example: netsched.sh -i eth0 -f 20480 -l 600 \n
"
}

# Default variable values
LimitNum=300
FlowNum=20480
InterfaceDev=

# Process arguments
while getopts ":i:d:f:l:v:h" opt ; do
	case "$opt" in

	  i) iflag=1
	     InterfaceDev="$OPTARG" ;;
	  d) dflag=1
	     InterfaceDev="$OPTARG" ;;
	  f) fflag=1
	     FlowNum=$OPTARG ;;
	  l) lflag=1
	     LimitNum=$OPTARG ;;
	  s) sflag=1
	      SendRate=$OPTARG ;;
	  r) rflag=1
	      ReceiveRate=$OPTARG ;;	
	  v) vflag=1
	      InterfaceDev=$OPTARG ;;
	    
	  h) ShowUsage;;
	  
	  ?) ShowUsage;;
	  
	esac
 
done

# Define the rest of the funtions.

ClearExistingQueue()
{
echo "removing shaping rules:"
# clean existing down- and uplink qdiscs, hide errors
sudo /sbin/tc qdisc del dev $InterfaceDev root 2> /dev/null > /dev/null 
sudo /sbin/tc qdisc del dev $InterfaceDev ingress 2> /dev/null > /dev/null
echo "complete"
}

SetQueue()
{
echo "Setting queue on interface $InterfaceDev, with a limit of $LimitNum packets and $FlowNum flows."
sudo /sbin/tc qdisc add dev $InterfaceDev root fq_codel target 3ms interval 40ms limit $LimitNum flows $FlowNum noecn quantum 1514
}

ShowQueue()
{
sudo  /sbin/tc -s qdisc ls dev $InterfaceDev
sudo  /sbin/tc -s class ls dev $InterfaceDev
}


if [[ "$iflag" == "1" ]]  ; then
    ClearExistingQueue ;
    SetQueue ;
 elif [[ "$vflag" == "1" ]] ; then
    ShowQueue ;
  elif   [[ "$dflag" == "1" ]] ; then
    ClearExistingQueue ;
  else
    ShowUsage ;
    exit 1
    fi