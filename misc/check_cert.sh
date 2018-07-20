#!/bin/bash
# Initial sketch of a simple SSL cert checking script.  Needs proper command line flags and input checking.
#Shostname=$1
#port=$2

which openssl &>/dev/null

[ $? -ne 0 ] && echo "Openssl is not available, please install it" && exit 1

ShowUsage() {
	printf "This script requires a hostname along with a port (though TCP port 443 is assumed if not provided).\n
-n	-- Hostname to connect to.\n
-p	-- Port of the service whose TLS certificate we wish to inpsect.\n
-h	-- Help (this text).\n

For example: check_cert.sh -n google.com -p 443\n
"
}

ExtractCert() {
	printf "\n Common name and subject alternative names:\n"

	awk '/X509v3 Subject Alternative Name/ {getline;gsub(/DNS:/,"",$0);gsub(/IPAddress:/,"",$0); print}' < <(

		openssl x509 -noout -text -in <(
			openssl s_client -ign_eof \
				-connect $hostname:$port -servername $hostname 2>/dev/null <<<$'HEAD / HTTP/1.0\r\n\r'))

	echo ""
	printf "Certificate details:\n"
	echo | openssl s_client -connect $hostname:$port 2>/dev/null | openssl x509 -noout -issuer -subject -dates -serial -email -fingerprint
}

while getopts "n:p:h" opt; do
	case "$opt" in

	n)
		nameflag=1
		hostname="$OPTARG"
		;;
	p)
		portflag=1
		port=$OPTARG
		;;
	h) ShowUsage ;;
	:) ShowUsage ;;
	esac

done

if
	[[ "$nameflag" == "1" ]] && [[ "$portflag" == "1" ]]
then
	ExtractCert
elif
	[[ "$nameflag" == "1" ]]
then
	port=443
	ExtractCert
else
	ShowUsage
	exit 1
fi
