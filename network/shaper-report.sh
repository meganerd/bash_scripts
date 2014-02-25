#!/bin/sh
DEV=$1
echo "Now list what we have set"
tc -s -d qdisc show
tc -s -d class show dev $DEV

