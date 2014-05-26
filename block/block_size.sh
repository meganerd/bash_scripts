#!/bin/bash

echo "Iterate through all the attached block devices, listing their physical and logical block sizes."

for each in /sys/block/sd? ; do echo $each ; echo physical ; cat $each/queue/physical_block_size ; echo logical ;cat $each/queue/logical_block_size ; echo "" ;done