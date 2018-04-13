#!/bin/bash
Log_Location="$HOME/temp/speedtest.log"
WebHostName="www.domain.tld"
# I usually generate a file with "dd if =/dev/urandom of=download.dat count=4900 bs=4k" 
# so that the resulting file aligns with 4k disk sectors. 
TestFileName="download.dat"
TestFileNamemd5="b792d74c36bacafd71f30c1a80077577"

echo "starting internal speedtest on:" `date`
wget -O /tmp/$TestFileName http://$WebHostName/$TestFileName --progress bar:force #-a $Log_Location 
echo `md5sum /tmp/$TestFileName |cut -f1 -d " "` > /tmp/$TestFileName-actual
echo $TestFileNamemd5 > /tmp/$TestFileName.md5
if cmp /tmp/$TestFileName-actual /tmp/$TestFileName.md5 #&> /dev/null  # Uncomment to suppress output
then echo "Test file appears to have downloaded correctly"
else echo "Test file is corrupt, please try again"
fi
# cleanup files in /tmp/
rm -f /tmp/$TestFileName*

