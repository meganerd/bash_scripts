#!/bin/bash
# Wrapper to easily set the CPU Frequency Governor
# dialog is a utility installed by default on all major Linux distributions.
# But it is good to check availability of dialog utility on your Linux box.

which dialog &> /dev/null

[ $? -ne 0 ]  && echo "Dialog utility is not available, please install it" && exit 1

# Check that a valid governor is set

# This section deprecated in favour of dialogue
#GOVERNOR=$1
#
#USAGE="This script requires a CPU governor as an argument, which should be one of: conservative, ondemand, userspace, powersave, performance
#For example: cpuscale.sh ondemand"
#
#if [ "$#" = "0" ]; then
#        echo "$USAGE"
#        exit 1
#fi

# Creating an array with each of the CPUs numeric ID
declare -a  CPUs=( `cat /proc/cpuinfo |grep processor |cut -f 2 -d \:` )

# Setting up the dialogue interface:
 dialog --clear --backtitle "Console Based CPU Governor Selection" --title "MAIN MENU" \
    --menu "Use [UP/DOWN] key to move" 18 100 6 \
    "performance" "Set for maximum performance, watch the temp!" \
    "ondemand"  "Usually the default, scale speed up as required." \
    "conservative"    "Conservatively scale up as required." \
    "powersave"     "Maximum power savings or lowest temp." \
    "userspace"      "Send control to a userspace application." \
    "EXIT"      "TO EXIT" 2> menuchoices.$$

# This computes the number of elements in the array, we use this to control our loop in the SetSpeed function
elements="${#CPUs[*]}"

SetSpeed ()
{  
  for (( i = 0  ; i < $elements ; i++ ))
  do sudo cpufreq-set -c ${CPUs[$i]} -g $GOVERNOR 
done
}

#echo "Setting CPU Frequency Governor $GOVERNOR"
#SetSpeed
#echo "Done"

retopt=$?
    choice=`cat menuchoices.$$`

    case $retopt in

           0) case $choice in

                  performance)  GOVERNOR=performance ; SetSpeed ;;
                  ondemand)   GOVERNOR=ondemand ; SetSpeed  ;;
                  conservative)     GOVERNOR=conservative ; SetSpeed  ;;
                  powersave)      GOVERNOR=powersave ; SetSpeed  ;;
                  userspace)       GOVERNOR=userspace ; SetSpeed ;;
                  EXIT)       clear; exit 0;;

              esac ;;

          *)clear ; exit ;;
    esac
