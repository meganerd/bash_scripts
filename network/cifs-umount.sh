#!/bin/bash
for each in `df -T |grep cifs |awk '{ print $7 }'` ; do sudo echo umount "$each" ; done
for each in `df -T |grep cifs |awk '{ print $7 }'` ; do sudo  umount "$each" ; done
echo done
