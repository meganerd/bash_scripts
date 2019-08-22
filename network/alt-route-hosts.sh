#!/bin/bash
# This script checks a text file for a list of IPs (one per line) and puts traffic from those IPs into the specified table.
# This script was designed to be called by a "post-up" line in a Debian based system (/etc/network/interfaces).
# You will need a table defined in /etc/iproute2/rt_tables.  See http://lartc.org/lartc.html#LARTC.RPDB.SIMPLE
# for more details on this.

host_list="/usr/local/etc/alt-routed-hosts.txt"
alt_table="CHANGEME"
alt_gateway="CHANGEME"
alt_dev="CHANGEME"

# Nothing should need to be modified below this line.
existing_table=`ip rule ls |grep $alt_table | cut -f 2 -d ":" | cut -f 2 -d " "`

echo ""
echo "Deleting current rules for IPs:"
for each in $existing_table ; do echo $each ; done
for each in $existing_table ; do ip rule del from $each table $alt_table ; done

echo ""
echo "Adding the following rules to the $alt_table table."
for each in `cat $host_list` ; do echo ip rule add from $each table $alt_table ; done

for each in `cat $host_list` ; do ip rule add from $each table $alt_table ; done
echo ""
echo "The current rule list is:"
ip rule ls

ip route flush table $alt_table
ip route add default via $alt_gateway dev $alt_dev table $alt_table
