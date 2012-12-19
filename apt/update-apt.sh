#! /bin/bash
TMP_FILE=/tmp/update-apt.txt
EMAIL=gustin+lan@meganerd.ca
PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/bin

apt-get update -qq
apt-get dist-upgrade -qq -d -y --force-yes
# On this system I am not using the -s flag which only simulates
# an install.  In this case I want to automatically install updates
#apt-get dist-upgrade -u -s > $TMP_FILE
apt-get dist-upgrade -u -y # > $TMP_FILE
#updates=`egrep "^[0-9]+ upgraded, [0-9]+ newly installed, [0-9]+ to remove and [0-9]+ not upgraded\.$" $TMP_FILE`
#upgrades=`echo $updates|cut -f1 -d" "`
#if [ $upgrades -gt 0 ]
#then
#  cat $TMP_FILE #|mail -s "$HOSTNAME apt-get upgrade" $EMAIL
#fi
#rm $TMP_FILE

