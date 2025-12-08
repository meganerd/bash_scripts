#!/bin/bash
df -T | grep cifs | awk '{ print $7 }' | while read -r each; do sudo echo umount "$each" ; done
df -T | grep cifs | awk '{ print $7 }' | while read -r each; do sudo umount "$each" ; done
echo "done"
