#!/bin/bash

# Function to get Jenkins builds for a job using full URL
get_jenkins_builds() {
    local full_job_url="$1"
    local netrc_file="$2"
    local start_time=$(date +%s)
    
    # Remove trailing slashes
    full_job_url="${full_job_url%/}"
    
    # Validate that this is a Jenkins job URL
    if [[ "$full_job_url" != *"/job/"* ]]; then
        echo "Error: Please provide a full Jenkins job URL containing '/job/'"
        echo "Example: https://jenkins.example.com/job/folder/job/jobname"
        exit 1
    fi
    
    # Extract base Jenkins URL (everything before /job/)
    jenkins_base="${full_job_url%%/job/*}"
    
    # Extract job path (everything after first /job/)
    job_path="${full_job_url#*/job/}"
    
    echo "Jenkins Base URL: $jenkins_base"
    echo "Job Path: $job_path"
    echo "=================================================="
    
    # Construct the API URL to get all builds
    # Handle nested jobs by ensuring proper /job/ structure
    if [[ "$job_path" == *"/job/"* ]]; then
        # Already has /job/ structure, use as-is
        api_job_path="job/${job_path}"
    else
        # Convert folder/job format to job/folder/job/jobname format
        api_job_path=""
        IFS='/' read -ra PATH_PARTS <<< "$job_path"
        for part in "${PATH_PARTS[@]}"; do
            if [ -n "$part" ]; then
                api_job_path="${api_job_path}/job/${part}"
            fi
        done
        api_job_path="${api_job_path#/}"  # Remove leading slash
    fi
    
    # Use URL-encoded query parameters to avoid issues with brackets and commas
    api_url="${jenkins_base}/${api_job_path}/api/json?tree=builds%5Bnumber%2Curl%2CdisplayName%2Cresult%2Ctimestamp%2Cduration%5D"
    
    # Validate the constructed URL
    if [[ "$api_url" == *"//"* ]] && [[ "$api_url" != "https://"* ]] && [[ "$api_url" != "http://"* ]]; then
        echo "Warning: Detected double slashes in URL, attempting to fix..."
        api_url="${api_url//\/\//\/}"
        echo "Fixed API URL: $api_url"
    fi
    
    # Make the API call
    if [ -n "$netrc_file" ] && [ -f "$netrc_file" ]; then
        echo "Using .netrc file: $netrc_file"
        response=$(curl -s -n --netrc-file "$netrc_file" "$api_url")
        curl_exit_code=$?
    else
        echo "Using default ~/.netrc for authentication (if it exists)"
        response=$(curl -s -n "$api_url")
        curl_exit_code=$?
    fi
    
    # If curl failed, show the error
    if [ $curl_exit_code -ne 0 ]; then
        echo "Error: curl command failed with exit code $curl_exit_code"
        echo "API URL: $api_url"
        echo ""
        echo "Troubleshooting:"
        echo "- Check if the Jenkins URL and job path are correct"
        echo "- Verify authentication in ~/.netrc or specified .netrc file"
        echo "- Ensure you have permissions to access this job"
        return 1
    fi
    
    # Check if the response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid response from Jenkins API"
        echo "Response: $response"
        echo ""
        echo "Troubleshooting:"
        echo "- Check if the Jenkins URL and job path are correct"
        echo "- Verify authentication in ~/.netrc or specified .netrc file"
        echo "- Ensure you have permissions to access this job"
        return 1
    fi
    
    
    # Extract total number of builds
    total_builds=$(echo "$response" | jq '.builds | length')
    
    echo "Total number of builds: $total_builds"
    echo ""
    echo "Build List:"
    echo "--------------------------------------------------------"
    echo "Build #  | Display Name | Result | Duration | Console URL"
    echo "---------|--------------|--------|----------|-------------"
    
    # Function to format duration from milliseconds to human readable
    format_duration() {
        local duration_ms=$1
        if [ "$duration_ms" = "null" ] || [ -z "$duration_ms" ]; then
            echo "N/A"
            return
        fi
        
        local duration_sec=$((duration_ms / 1000))
        local hours=$((duration_sec / 3600))
        local minutes=$(((duration_sec % 3600) / 60))
        local seconds=$((duration_sec % 60))
        
        if [ $hours -gt 0 ]; then
            printf "%dh %dm %ds" $hours $minutes $seconds
        elif [ $minutes -gt 0 ]; then
            printf "%dm %ds" $minutes $seconds
        else
            printf "%ds" $seconds
        fi
    }
    
    # Process each build and format output
    echo "$response" | jq -r '.builds[] | 
        "\(.number) | \(.displayName // "Build #\(.number)") | \(.result // "UNKNOWN") | \(.duration // "null") | \(.url)console"' | 
        sort -nr | 
        while IFS='|' read -r number display_name result duration console_url; do
            formatted_duration=$(format_duration "$duration")
            printf "%-8s | %-12s | %-8s | %-8s | %s\n" "$number" "$display_name" "$result" "$formatted_duration" "$console_url"
        done
    
    # Calculate and display execution time
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    echo ""
    echo "=================================================="
    echo "Execution completed in ${execution_time} seconds"
}

# Show usage information
show_usage() {
    echo "Usage: $0 <full_jenkins_job_url> [netrc_file]"
    echo ""
    echo "This script uses .netrc authentication for secure credential management."
    echo "Authentication is handled via .netrc files (default: ~/.netrc)"
    echo ""
    echo "Examples:"
    echo ""
    echo "1. Simple job (uses ~/.netrc for auth):"
    echo "   $0 \"https://jenkins.example.com/job/job-name\""
    echo ""
    echo "2. Nested job:"
    echo "   $0 \"https://jenkins.example.com/job/folder1/job/subfolder/job/jobname\""
    echo ""
    echo "3. With custom .netrc file:"
    echo "   $0 \"https://jenkins.example.com/job/folder/job/jobname\" \"/path/to/custom.netrc\""
    echo ""
    echo "4. Public Jenkins (no authentication needed):"
    echo "   $0 \"https://ci.jenkins.io/job/job-name\""
    echo ""
    echo ".netrc file format:"
    echo "machine jenkins.example.com"
    echo "login your-username"
    echo "password your-api-token"
    echo ""
    echo "To get your API token:"
    echo "- Go to Jenkins -> Your Profile -> Configure -> API Token -> Add new Token"
    echo ""
    echo "Note: Ensure .netrc file has proper permissions (600): chmod 600 ~/.netrc"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed."
    echo "Please install jq: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
    exit 1
fi

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    show_usage
    exit 1
fi

# Call the function with provided arguments
get_jenkins_builds "$1" "$2"
