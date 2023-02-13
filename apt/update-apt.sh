#! /bin/bash
echo "Beginning update at $(date)"
EMAIL=user@domain.tld
PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/bin

apt update && apt upgrade -y && apt autoremove -y

echo "Reinstalling packages that were skipped."

for each in $(sudo apt list --upgradable |grep -v Listing |cut -f 1 -d "/") ; do sudo apt reinstall -y $each ; done

echo "Completing update at $(date)"
