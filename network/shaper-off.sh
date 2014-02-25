#!/bin/sh
# shaper-off.sh

DEV=$1

USAGE="This script requires an ethernet device as an argument.
For example: shaper.sh eth0"

if [ "$#" = "0" ]; then
        echo "$USAGE"
        exit 1
fi

echo "removing shaping rules:"
# clean existing down- and uplink qdiscs, hide errors
tc qdisc del dev $DEV root
tc qdisc del dev $DEV ingress 
echo "complete"
