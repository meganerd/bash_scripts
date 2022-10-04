#!/usr/bin/env bash
# Based on https://gist.github.com/sebble/e5af3d03700bfd31c62054488bfe8d4f#file-stars-sh

USER=$1

if ! command -v jq &>/dev/null; then                                                                               
    echo "jq was not found and is required, please install it or add it to your path." && exit 1                                                        
fi                                                                                                                      

if [[ "$USER" == "" ]] ; then
    echo "No user specified.  Please pass your github username as the first parameter to this script."
    exit 2
fi
STARS=$(curl --netrc-optional -sI https://api.github.com/users/"$USER"/starred?per_page=1 | grep -E '^link'| grep -E -o 'page=[0-9]+'|tail -1|cut -c6-)
PAGES=$((658/100+1))

if [[ "$STARS" == "" ]] ; then
    echo "No starred repositories found."
fi

echo "You have $STARS starred repositories."
sleep 1

printCSV () {
# When using CSV output you will need to trim the first line by piping to "tail -n +2"
for PAGE in $(seq $PAGES); do
    curl --netrc-optional -sH "Accept: application/vnd.github.v3.star+json" "https://api.github.com/users/$USER/starred?per_page=100&page=$PAGE"|jq -r '.[]|[.starred_at,.repo.full_name,.repo.url,.repo.description]|@csv'
done
}

printShort () {
for PAGE in $(seq $PAGES); do
curl --netrc-optional -sH "Accept: application/vnd.github.v3.star+json" "https://api.github.com/users/$USER/starred?per_page=100&page=$PAGE"|jq -r '.[]|[.starred_at,.repo.full_name] | @tsv'
done
}

printDetailed () {
for PAGE in $(seq $PAGES); do
    curl --netrc-optional -sH "Accept: application/vnd.github.v3.star+json" "https://api.github.com/users/$USER/starred?per_page=100&page=$PAGE"|jq -r '.[]|[.starred_at,.repo.full_name,.repo.url,.repo.description]'
done
}

if [[ "$2" = "csv" ]] ; then
printCSV
elif [[ "$2" = "detail" ]] ; then 
printDetailed
else
printShort
fi