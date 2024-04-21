#!/usr/bin/env bash

if [ -z "$2" ];
    then listSize=25
else 
    listSize=$2    
fi

curl -L -s "https://registry.hub.docker.com/v2/repositories/library/$1/tags?page_size=$listSize" | jq '."results"[]["name"]' 

# docker image inspect --format '{{json .}}' $1 | jq -r '. | {Id: .Id, RepoTags: .RepoTags, Digest: .Digest, RepoDigests: .RepoDigests }'
