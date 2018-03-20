#!/bin/bash
longurl () {
  url="$1"
  while [ "$url" ]; do
    echo "$url"
    line=$(curl -sI "$url" | grep -P '^[Ll]ocation:\s' | head -n 1)
    url=$(echo "$line" | sed -r 's/^[Ll]ocation:\s+(\S.*\S)\s*$/\1/g')
	# The below pipes the output to the clipboard.  Will be implemented when proper argument handling is added.
	#echo -n "$url" | sed -r 's/^https?:\/\/([^/]+).*\/.*$/\1/g' | xclip -selection clipboard
	echo -n "$url" | sed -r 's/^https?:\/\/([^/]+).*\/.*$/\1/g' 
  done
}
