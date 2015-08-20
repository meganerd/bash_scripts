#!/bin/bash
# This extracts the requested pages from a PDF into a new pdf.

# Check for the existance of GhostScript (gs).

which gs &> /dev/null

[ $? -ne 0 ]  && echo "GhostScript utility is not available, please install it" && exit 1

ShowUsage()
{
printf "This script requires an input file name along with the page range to extract.\n
-f	-- First page of desired range.\n
-l	-- last page of desired range.\n
-i	-- Input filename to extract from.\n
-h	-- Help (this text).\n

For example: extract-pages.sh -i mypdf.pdf -f 3 -l 5\n
"
}

ExtractPages()
{
gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER \
       -dFirstPage=$FirstPage -dLastPage=$LastPage -sOutputFile="$InFile"-p"$FirstPage"-p"$LastPage".pdf "$InFile" 
}

# Check to see if there were any parameters passed, if not, display basic usage example.
#if [ "$#" = "0" ]; then
#        ShowUsage
#        exit 1
#fi

while getopts "i:f:l:h" opt ; do
	case "$opt" in

	  i) iflag=1
	     InFile="$OPTARG" ;;
	  f) fflag=1
	     FirstPage=$OPTARG ;;
	  l) lflag=1
	     LastPage=$OPTARG ;;
	  h) ShowUsage;;
	  :) ShowUsage;;
	esac
 
done

if [[ "$iflag" == "1" ]] && [[ "$fflag" == "1" ]] && [[ "$lflag" == "1" ]] ; then
    ExtractPages ;
  else
    ShowUsage ;
    exit 1
    fi
 
