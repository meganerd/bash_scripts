#!/bin/bash
# Simple script to determine external IP address
curl ipinfo.io/ip | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
