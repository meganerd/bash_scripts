#!/bin/bash
# Based on script from https://superuser.com/a/380598/657382

ShowUsage() {
    printf "\nThis script requires one of three keys to be specified CapsLock, NumLock, or ScrollLock (caps, num, scroll respectively).
-k keyname	-- Key to blink.
-h	        -- Help (this text).

For example: hdd-keyboard-led.sh -k scroll.\n
"
}

if [[ $EUID -ne 0 ]]; then
   printf "This script usually needs to be run as root.  If it works for you 
great, but chances are you are going to get permission denied messages below 
this one.\n\n"
fi
printf "Press Ctrl-c to exit.\n"

while getopts "k:h" opt; do
    case ${opt} in

    k) 
        keyflagflag=1
        usekey=${OPTARG}
        ;;
    h) ShowUsage ;;
    *) ShowUsage ;;
    esac

if [[ $usekey == scroll || $usekey == num || $usekey == caps ]] ; then
echo "using $usekey"
else 
ShowUsage ; exit 1 ;
fi

done
# Check interval seconds
CHECKINTERVAL=0.1

# console
CONSOLE=/dev/console

#indicator to use [caps, num, scroll]
INDICATOR=$usekey

getVmstat() {
  cat /proc/vmstat|egrep "pgpgin|pgpgout"  
}
#turn led on
function led_on()
{
    setleds -L +${INDICATOR} < ${CONSOLE}
}
#turn led off
function led_off()
{
    setleds -L -${INDICATOR} < ${CONSOLE}
}
# initialise variables
NEW=$(getVmstat)
OLD=$(getVmstat)
## 
while [ 1 ] ; do
  sleep $CHECKINTERVAL # slowdown a bit
  # get status 
  NEW=$(getVmstat)
  #compare state
  if [ "$NEW" = "$OLD" ]; then  
    led_off ## no change, led off
  else
    led_on  ## change, led on
  fi
  OLD=$NEW  
done