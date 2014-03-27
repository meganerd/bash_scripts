#!/bin/bash
# Initial sketch of a simple SSL cert checking script.  Needs proper command line flags and input checking.
hostname=$1
port=$2
 echo | openssl s_client -connect $hostname:$port 2>/dev/null | openssl x509 -noout -issuer -subject -dates
