#!/bin/bash

# Default values
DEFAULT_NUM_JOBS=20
DEFAULT_OUTPUT_DIR="$HOME/Downloads"

# Parse arguments
JENKINS_URL=""
NUM_JOBS=$DEFAULT_NUM_JOBS
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

# Check if we have at least the URL
if [ $# -lt 1 ]; then
  echo "Usage: $0 <jenkins-url> [num-jobs] [output-dir]"
  echo "Example: $0 https://prod.jenkins.onetrust.dev/job/Infrastructure-Maintenance/job/sql-db-maintenance-schedule/job/db-maintainer/ 5 ~/db-maint/"
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

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Fetch the list of builds (ensure URL ends with /)
if [[ ! "$JENKINS_URL" =~ /$ ]]; then
  JENKINS_URL="${JENKINS_URL}/"
fi

echo "Fetching builds from: $JENKINS_URL"
BUILDS=$(curl --netrc --silent "$JENKINS_URL/api/json?depth=1" | jq -r ".builds[0:$NUM_JOBS] | .[].number" 2>/dev/null)

if [ -z "$BUILDS" ]; then
  echo "Error: No builds found. Check URL, auth, or if jq is installed."
  exit 1
fi

echo "Found builds: $BUILDS"

# For each build, download console log (CORRECT URL: no /build/ prefix)
SUCCESS_COUNT=0
for BUILD_NUM in $BUILDS; do
  LOG_URL="${JENKINS_URL}${BUILD_NUM}/consoleText"  # Fixed: Directly append build number
  LOG_FILE="${OUTPUT_DIR}/job_${BUILD_NUM}.txt"

  echo "Fetching log for build $BUILD_NUM from: $LOG_URL"

  # Download with status check (matching your direct curl: --netrc, no -L, --silent for clean output)
  RESPONSE=$(curl --netrc -w "\nHTTP_CODE:%{http_code}" --silent --max-time 300 "$LOG_URL")
  CURL_EXIT=$?
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1 | sed 's/.*HTTP_CODE://')
  CONTENT=$(echo "$RESPONSE" | sed '$d')  # Remove the HTTP_CODE line

  if [ $CURL_EXIT -eq 0 ] && [ "$HTTP_CODE" = "200" ] && [ ${#CONTENT} -gt 100 ] && [[ "$CONTENT" != *"<html"* ]]; then
    echo -e "$CONTENT" > "$LOG_FILE"
    echo "  ✓ Downloaded log for build $BUILD_NUM to $LOG_FILE (${#CONTENT} chars)"
    ((SUCCESS_COUNT++))
  else
    echo "  ✗ Failed build $BUILD_NUM: Curl exit $CURL_EXIT, HTTP $HTTP_CODE (content length: ${#CONTENT})"
    echo "  First 100 chars: ${CONTENT:0:100}..."
    # Save error content to .error file
    echo -e "$CONTENT" > "${LOG_FILE}.error"
    echo "  Error details saved to ${LOG_FILE}.error"
  fi
done

echo "Done. Successfully downloaded $SUCCESS_COUNT out of $(echo $BUILDS | wc -w) logs."
