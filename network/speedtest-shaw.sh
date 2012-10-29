#!/bin/bash
wget -O /tmp/download.dat http://downloads.shaw.ca/ShawCA/speedtest/download.dat
echo `md5sum /tmp/download.dat |cut -f1 -d " "` > /tmp/download.dat-actual
echo b792d74c36bacafd71f30c1a80077577 > /tmp/download.dat.md5
if cmp /tmp/download.dat-actual /tmp/download.dat.md5 &> /dev/null  # Suppress output
then echo "File appears to have downloaded correctly"
else echo "File is corrupt, please try again"
fi
#cleanup
rm -f /tmp/download.dat*

#exit 0

