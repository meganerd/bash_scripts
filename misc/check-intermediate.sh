#!/bin/bash
which openssl &>/dev/null

[ $? -ne 0 ] && echo "Openssl is not available, please install it" && exit 1

ShowUsage() {
	printf "This script requires a hostname along with a port (though TCP port 443 is assumed if not provided).  
    It will then print the details of the TLS/SSL intermediate certificate.\n
-n	-- Hostname to connect to.\n
-p	-- Port of the service whose TLS certificate we wish to inpsect.\n
-h	-- Help (this text).\n

For example: check-intermediate.sh -n google.com -p 443\n
"
}

PrintCert() {
    	echo ""
	printf "Certificate details:\n"
	echo | openssl s_client -showcerts -servername $server_name -connect $server_name:$server_port 2>/dev/null | openssl x509 -inform pem -noout -text
}

while getopts "n:p:h" opt; do
	case "$opt" in

	n)
		nameflag=1
		server_name="$OPTARG"
		;;
	p)
		portflag=1
		server_port=$OPTARG
		;;
	h) ShowUsage ;;
	:) ShowUsage ;;
	esac

done

if
	[[ "$nameflag" == "1" ]] && [[ "$portflag" == "1" ]]
then
	PrintCert
elif
	[[ "$nameflag" == "1" ]]
then
	server_port=443
	PrintCert
else
	ShowUsage
	exit 1
fi

