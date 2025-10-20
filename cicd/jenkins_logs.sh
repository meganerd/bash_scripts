#!/bin/bash

# Default values
DEFAULT_NUM_JOBS=20
DEFAULT_OUTPUT_DIR="$HOME/Downloads"
DEFAULT_NETRC="$HOME/.netrc"

# Initialize variables
JENKINS_URL=""
NUM_JOBS=$DEFAULT_NUM_JOBS
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
NETRC_FILE="$DEFAULT_NETRC"
SHOW_HELP=false

ShowUsage() {
    cat << EOF
This script retrieves Jenkins build logs for a specified job.

Usage: $0 --url <jenkins-url> [OPTIONS]

Required Parameters:
  --url <url>           Jenkins job URL

Optional Parameters:
  --num-jobs <number>   Number of recent builds to retrieve (default: $DEFAULT_NUM_JOBS)
  --output-dir <path>   Directory to store downloaded logs (default: $DEFAULT_OUTPUT_DIR)
  --netrc <path>        Path to netrc file for authentication (default: $DEFAULT_NETRC)
  --help, -h           Show this help message

Examples:
  $0 --url https://prod.jenkins.mydomain.tld/job/Infrastructure/job/maintenance/job/maint/
  $0 --url https://jenkins.example.com/job/myproject/ --num-jobs 5 --output-dir ~/jenkins-logs/
  $0 --url https://jenkins.example.com/job/myproject/ --netrc ~/.netrc.custom
EOF
}

# Function to extract hostname from URL
extract_hostname() {
    local url="$1"
    # Remove protocol (http:// or https://)
    local host="${url#http://}"
    host="${host#https://}"
    # Remove path (everything after first /)
    host="${host%%/*}"
    # Remove port if present
    host="${host%%:*}"
    echo "$host"
}

# Function to check if machine entry exists in netrc file
check_netrc_machine() {
    local netrc_file="$1"
    local hostname="$2"

    # Check if netrc file exists
    if [ ! -f "$netrc_file" ]; then
        echo "Error: Netrc file not found: $netrc_file"
        return 1
    fi

    # Check file permissions (netrc should be readable only by owner)
    local perms=$(stat -c %a "$netrc_file" 2>/dev/null || stat -f %A "$netrc_file" 2>/dev/null)
    if [ -n "$perms" ] && [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
        echo "Warning: Netrc file has insecure permissions ($perms). Should be 600 or 400."
        echo "  Run: chmod 600 $netrc_file"
    fi

    # Search for machine entry in netrc file
    # netrc format: machine <hostname> login <user> password <pass>
    if grep -q "^[[:space:]]*machine[[:space:]]\+${hostname}\([[:space:]]\|$\)" "$netrc_file"; then
        echo "✓ Found machine entry for '$hostname' in $netrc_file"
        return 0
    else
        echo "Error: No machine entry found for '$hostname' in $netrc_file"
        echo ""
        echo "Please add an entry to your netrc file in the following format:"
        echo "  machine $hostname"
        echo "  login your-username"
        echo "  password your-password-or-token"
        echo ""
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            JENKINS_URL="$2"
            shift 2
            ;;
        --num-jobs)
            NUM_JOBS="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --netrc)
            NETRC_FILE="$2"
            shift 2
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Error: Unknown parameter '$1'"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
    ShowUsage
    exit 0
fi

# Validate required parameters
if [ -z "$JENKINS_URL" ]; then
    echo "Error: --url parameter is required"
    echo "Use --help for usage information."
    exit 1
fi

# Validate URL format
if [[ ! "$JENKINS_URL" =~ ^https?:// ]]; then
    echo "Error: Invalid URL format. URL must start with http:// or https://"
    exit 1
fi

# Validate num-jobs is a positive integer
if ! [[ "$NUM_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --num-jobs must be a positive integer (got: '$NUM_JOBS')"
    exit 1
fi

# Validate output directory path
if [ -z "$OUTPUT_DIR" ]; then
    echo "Error: --output-dir cannot be empty"
    exit 1
fi

# Extract hostname and check netrc file
JENKINS_HOST=$(extract_hostname "$JENKINS_URL")
if ! check_netrc_machine "$NETRC_FILE" "$JENKINS_HOST"; then
    exit 1
fi

# Display parsed parameters
echo ""
echo "Parameters:"
echo "  Jenkins URL: $JENKINS_URL"
echo "  Jenkins Host: $JENKINS_HOST"
echo "  Number of jobs: $NUM_JOBS"
echo "  Output directory: $OUTPUT_DIR"
echo "  Netrc file: $NETRC_FILE"
echo ""

# Ensure output directory exists
if ! mkdir -p "$OUTPUT_DIR"; then
    echo "Error: Failed to create output directory: $OUTPUT_DIR"
    exit 1
fi

# Ensure URL ends with /
if [[ ! "$JENKINS_URL" =~ /$ ]]; then
    JENKINS_URL="${JENKINS_URL}/"
fi

echo "Fetching builds from: $JENKINS_URL"
BUILDS=$(curl --netrc-file "$NETRC_FILE" --silent "$JENKINS_URL/api/json?depth=1" | jq -r ".builds[0:$NUM_JOBS] | .[].number" 2>/dev/null)

if [ -z "$BUILDS" ]; then
    echo "Error: No builds found. Check URL, auth, or if jq is installed."
    exit 1
fi

echo "Found builds: $BUILDS"

# For each build, download console log
SUCCESS_COUNT=0
for BUILD_NUM in $BUILDS; do
    LOG_URL="${JENKINS_URL}${BUILD_NUM}/consoleText"
    LOG_FILE="${OUTPUT_DIR}/job_${BUILD_NUM}.txt"

    echo "Fetching log for build $BUILD_NUM from: $LOG_URL"

    # Download with status check
    RESPONSE=$(curl --netrc-file "$NETRC_FILE" -w "\nHTTP_CODE:%{http_code}" --silent --max-time 300 "$LOG_URL")
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
