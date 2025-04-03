#!/bin/bash
# This script checks a Debian like system to see if there is a pending reboot.
# This script then reboots the system after the specified interval.  Use with | tee in 
# crontab for logging.

reboot_interval="5"
current_date="`date`"

if [ -f /var/run/reboot-required ]
      	then echo "Reboot required at $current_date, will reboot in $reboot_interval minutes." ;
#	if [[ $EUID -ne 0 ]]; then sudo /sbin/shutdown -r +$reboot_interval;
#	else /sbin/shutdown -r +$reboot_interval;
#	fi
else echo "No reboot required at this time ($current_date)."
fi
#exit 0
