#! /bin/bash
echo "Beginning update at $(date)"
EMAIL=user@domain.tld
PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/bin

apt update && apt upgrade -y && apt autoremove -y

echo "Completing update at $(date)"