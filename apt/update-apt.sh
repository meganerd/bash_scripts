#! /bin/bash
EMAIL=changeme@domain.tld
PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/bin

aptitude update -qq
aptitude dist-upgrade -qq -d -y --force-yes

# On this system I am not using the -s flag which only simulates 
# an install.  In this case I want to automatically install updates.  To simulate 
# add the -s flag to apt-get.

aptitude safe-upgrade -u -y
