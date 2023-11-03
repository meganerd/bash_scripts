#!/usr/bin/env bash

curl -L -s 'https://registry.hub.docker.com/v2/repositories/library/ubuntu/tags?page_size=1024'|jq '."results"[]["name"]' |grep jammy |head -n1
