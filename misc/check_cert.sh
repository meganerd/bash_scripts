#!/bin/bash
# Initial sketch of a simple SSL cert checking script.  Needs proper command line flags and input checking.
hostname=$1
port=$2

echo "Common name and subject alternative names:"

sed -ne 's/^\( *\)Subject:/\1/p;/X509v3 Subject Alternative Name/{
    N;s/^.*\n//;:a;s/^\( *\)\(.*\), /\1\2\n\1/;t;p;q; }' < <(
    openssl x509 -noout -text -in <(
        openssl s_client -ign_eof 2>/dev/null <<<$'HEAD / HTTP/1.0\r\n\r' \
            -connect $hostname:$port ) )
echo ""
echo "Certificate details:"
echo | openssl s_client -connect $hostname:$port 2>/dev/null | openssl x509 -noout -issuer -subject -dates -serial -email -fingerprint
