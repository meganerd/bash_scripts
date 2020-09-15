#!/usr/bin/env /bin/bash

if ! command -v jq &>/dev/null; then
    echo "jq json parser is not available, please install it" && exit 1
fi

if [ -z $REMOTEREPOURL ]; then
  echo 'One or more variables are undefined.
  Please define remote URL of Docker repo environment variable REMOTEREPOURL'
  exit 1
fi

function listTags() {
    local repo=${1}
    local size=${2:-25}
    local page=${3:-1}
    [ -z "${repo}" ] && echo "Usage: listTags <repoName> [size] [pageIndex]" 1>&2 && return 1
    curl "$REMOTEREPOURL/${repo}/tags?page=${page}&page_size=${size}" 2>/dev/null | jq -r '.results[].name' | sort
}