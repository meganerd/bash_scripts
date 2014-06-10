#!/bin/bash
# displays the current cpu speed in the top right corner.

cspeed=`grep MHz /proc/cpuinfo|cut -f2 -d ":"|cut -f1 -d"."` 

# define functions

#function 
display.speed ()
{
#echo $cspeed |osd_cat -p top -c red -u black -O 1 -A right -o 30 ;  
echo $cspeed |osd_cat -p top -c red -u black -O 1 -A right -o 30 ;  
}

#while true ; do  display.speed && sleep 1 ; done
display.speed
#sleep 5

#function get.speed {cspeed=`grep MHz /proc/cpuinfo|cut -f2 -d ":"|cut -f1 -d"."` ;}


