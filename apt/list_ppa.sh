#! /bin/sh 
# This script lists all of the installed PPA.  Useful for building similar machines
# or doing a patch purge with ppa-purge of all PPAs.
 
for each_ppa in `find /etc/apt/ -name \*.list`; do
    grep -o "^deb http://ppa.launchpad.net/[a-z0-9\-]\+/[a-z0-9\-]\+" $each_ppa | while read ENTRY ; do
        USER=`echo $ENTRY | cut -d/ -f4`
        PPA=`echo $ENTRY | cut -d/ -f5`
        echo $USER/$PPA
    done
done
