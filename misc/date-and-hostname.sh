#!/bin/bash
# Based on ideas found at http://www.cyberciti.biz/faq/linux-unix-sleep-bash-scripting/
#

while [ : ]
do
    clear
    tput cup 5 5
    date
    tput cup 6 5
    echo "Hostname : $(hostname)"
    sleep 30
done
