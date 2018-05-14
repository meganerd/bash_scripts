#!/bin/bash
# Brief output.  Will be a parameter option in an upcoming revision
#smem -t -k -c pss -P $1 | tail -n 1

# Check for the existance of smem
which smem &>/dev/null

[ $? -ne 0 ] && echo "smem utility is not available, please install it" && exit 1

ShowUsage() {
	printf "This script requires a process name.  For best results use the full path of the application (eg. /opt/google/chrome/chrome). \n
-p	-- Process name or path.\n
-s  -- Short output (total of pss usage only).
-h	-- Help (this text).\n

For example: memuse.sh -p /opt/google/chrome/chrome \n
"
}

# Setting default value of variable(s).
ShortOutput="false"

MemUseLong() {
	smem -t -k -P $ProcessName
}

MemUseShort() {
	smem -t -k -c pss -P $ProcessName | tail -n 1
}

while getopts ":p:s" opt; do
	case "$opt" in

	p)
		PName=1
		ProcessName="$OPTARG"
		;;
	s)
		shortflag=1
		ShortOutput="true"
		;;
	h) ShowUsage ;;
	?) ShowUsage ;;
	:) ShowUsage:: ;;
	esac
done

if [[ "$ShortOutput" == "true" ]]; then
	MemUseShort
elif [[ "$ShortOutput" == "false" ]]; then
	MemUseLong
else
	ShowUsage
	exit 1
fi
