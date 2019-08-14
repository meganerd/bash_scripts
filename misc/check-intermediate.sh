#!/bin/bash
server_port=443
server_name=$1
echo | openssl s_client -showcerts -servername $server_name -connect $server_name:$server_port 2>/dev/null | openssl x509 -inform pem -noout -text

