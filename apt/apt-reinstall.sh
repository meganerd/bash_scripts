#!/usr/bin/env bash
for each in $(sudo apt list --upgradable |grep -v Listing |cut -f 1 -d "/") ; do sudo apt reinstall -y $each ; done
