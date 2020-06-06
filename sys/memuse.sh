#!/bin/bash
# Brief output.  Will be a parameter option in an upcoming revision
#smem -t -k -c pss -P $1 | tail -n 1

# Check for the existance of smem
which smem &>/dev/null

[ $? -ne 0 ] && echo "smem utility is not available, please install it" && exit 1

ShowUsage() {
	printf "This script requires a process name.  For best results use the full path of the application (eg. /opt/google/chrome/chrome). \n
-p  -- Process name or path.  If left blank smem -w will be used instead.
-s  -- Short output (total of pss usage only).
-h  -- Help (this text).

For example: memuse.sh -p /opt/google/chrome/chrome \n
"
}

# Setting default value of variable(s).
ShortOutput="False"

MemUseLong() {
	if [ -z "$ProcessName" ];
		then echo "No process name specified (use -h for details), defaulting to summary:" ;
		smem -t -k -c "pss name pid user" -s pss;
	else
	smem -t -k -P $ProcessName
	fi
}

MemUseShort() {
	if [ -z "$ProcessName" ];
		then echo "Short summary specified (use -h for details)." ;
		smem -t -k -c "pss name pid user"  | (head -n 1 && tail -n 10) ;
	else
		smem -t -k -c pss -P $ProcessName | tail -n 1
	fi
}

while getopts ":p:sh" opt; do
	case "$opt" in

	p)
		PName=1
		ProcessName="$OPTARG"
		;;
	s)
		shortflag=1
		ShortOutput="True"
		;;
	h) ShowUsage=1 
		ShowHelp="True"
		;;
	:) ShowUsage:: ;;
		esac
done

if [[ "$ShowHelp" == "True" ]]; then
	ShowUsage;
	exit 1
elif [[ "$ShortOutput" == "True" ]]; then
	MemUseShort
elif [[ "$ShortOutput" == "False" ]]; then
	MemUseLong
else
	ShowUsage
	exit 1
fi
