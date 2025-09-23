#!/bin/bash

# Default values
DEFAULT_NUM_JOBS=20
DEFAULT_OUTPUT_DIR="$HOME/Downloads"

# Parse arguments
JENKINS_URL=""
NUM_JOBS=$DEFAULT_NUM_JOBS
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
NETRC_FILE=~/.netrc

# Check if we have at least the URL
if [ $# -lt 1 ]; then
  echo "Usage: $0 <jenkins-url> [num-jobs] [output-dir] [netrc-file]"
  exit 1
fi

JENKINS_URL="$1"
shift

if [ $# -gt 0 ]; then
  NUM_JOBS="$1"
  shift
fi

if [ $# -gt 0 ]; then
  OUTPUT_DIR="$1"
  shift
fi

if [ $# -gt 0 ]; then
  NETRC_FILE="$1"
  shift
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Fetch the list of builds
BUILDS=$(curl --netrc --silent "$JENKINS_URL/api/json" | jq -r ".builds[0:$NUM_JOBS] | .[].number")

# For each build, download console log
for BUILD_NUM in $BUILDS; do
  LOG_URL="${JENKINS_URL}build/${BUILD_NUM}/consoleText"
  LOG_FILE="${OUTPUT_DIR}/job_${BUILD_NUM}.txt"
  curl --netrc --silent "$LOG_URL" > "$LOG_FILE"
  echo "Downloaded log for build $BUILD_NUM to $LOG_FILE"
done

exit 0
