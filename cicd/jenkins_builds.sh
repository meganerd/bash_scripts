#!/bin/bash

# Function to parse job URL and extract Jenkins base URL and job path
parse_job_url() {
    local input_url="$1"
    
    # Remove trailing slashes
    input_url="${input_url%/}"
    
    # Check if this looks like a full job URL
    if [[ "$input_url" == *"/job/"* ]]; then
        # Extract base Jenkins URL (everything before /job/)
        jenkins_base="${input_url%%/job/*}"
        
        # Extract job path (everything after first /job/)
        job_path="${input_url#*/job/}"
        
        # Convert job path to API format
        # Replace /job/ with /job/ but handle nested structure
        api_job_path="${job_path//\/job\//\/job\/}"
        
        echo "${jenkins_base}|${api_job_path}"
    else
        # Assume it's just a job name or simple path
        echo "|${input_url}"
    fi
}

# Function to get Jenkins builds for a job
get_jenkins_builds() {
    local jenkins_url="$1"
    local job_input="$2"
    local netrc_file="$3"
    
    # Parse the job input to handle full URLs or simple job names
    local parse_result
    parse_result=$(parse_job_url "$job_input")
    
    local base_url job_path
    IFS='|' read -r base_url job_path <<< "$parse_result"
    
    # Determine final Jenkins URL and job path
    if [ -n "$base_url" ]; then
        # Full URL was provided
        final_jenkins_url="$base_url"
        final_job_path="$job_path"
        echo "Detected full job URL"
        echo "Jenkins Base URL: $final_jenkins_url"
        echo "Job Path: $final_job_path"
    else
        # Simple job name was provided
        final_jenkins_url="$jenkins_url"
        final_job_path="$job_path"
        echo "Using provided Jenkins URL with job name/path"
        echo "Jenkins URL: $final_jenkins_url"
        echo "Job Name/Path: $final_job_path"
    fi
    
    echo "=================================================="
    
    # Construct the API URL to get all builds
    # Handle nested jobs by ensuring proper /job/ structure
    if [[ "$final_job_path" == *"/"* ]] && [[ "$final_job_path" != *"/job/"* ]]; then
        # Convert folder/job format to job/folder/job/jobname format
        api_job_path=""
        IFS='/' read -ra PATH_PARTS <<< "$final_job_path"
        for part in "${PATH_PARTS[@]}"; do
            if [ -n "$part" ]; then
                api_job_path="${api_job_path}/job/${part}"
            fi
        done
        api_job_path="${api_job_path#/}"  # Remove leading slash
    else
        api_job_path="job/${final_job_path}"
    fi
    
    api_url="${final_jenkins_url}/${api_job_path}/api/json?tree=builds[number,url,displayName,result,timestamp]"
    
    # Prepare curl command with .netrc authentication
    curl_cmd="curl -s -n"
    
    # Add custom .netrc file if provided
    if [ -n "$netrc_file" ]; then
        if [ -f "$netrc_file" ]; then
            curl_cmd="$curl_cmd --netrc-file \"$netrc_file\""
            echo "Using .netrc file: $netrc_file"
        else
            echo "Warning: Specified .netrc file '$netrc_file' does not exist"
            echo "Falling back to default ~/.netrc"
        fi
    else
        echo "Using default ~/.netrc for authentication (if it exists)"
    fi
    
    echo "API URL: $api_url"
    echo ""
    
    # Make the API call
    response=$(eval "$curl_cmd \"$api_url\"")
    
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
    echo "----------------------------------------"
    echo "Build #  | Display Name | Result | Console URL"
    echo "---------|--------------|--------|-------------"
    
    # Process each build and format output
    echo "$response" | jq -r '.builds[] | 
        "\(.number) | \(.displayName // "Build #\(.number)") | \(.result // "UNKNOWN") | \(.url)console"' | 
        sort -nr | 
        while IFS='|' read -r number display_name result console_url; do
            printf "%-8s | %-12s | %-8s | %s\n" "$number" "$display_name" "$result" "$console_url"
        done
}

# Show usage information
show_usage() {
    echo "Usage: $0 <jenkins_url_or_full_job_url> <job_name_or_empty> [netrc_file]"
    echo ""
    echo "This script uses .netrc authentication for secure credential management."
    echo "Authentication is handled via .netrc files (default: ~/.netrc)"
    echo ""
    echo "The script can handle both simple job names and nested jobs in folders."
    echo "You can provide either:"
    echo "  1. Jenkins base URL + job name/path"
    echo "  2. Full job URL (script will extract base URL and job path)"
    echo ""
    echo "Examples:"
    echo ""
    echo "1. Simple job (uses ~/.netrc for auth):"
    echo "   $0 \"https://jenkins.example.com\" \"job-name\""
    echo ""
    echo "2. Nested job using folder/job format:"
    echo "   $0 \"https://jenkins.example.com\" \"folder1/subfolder/jobname\""
    echo ""
    echo "3. Using full job URL (script extracts everything automatically):"
    echo "   $0 \"https://jenkins.example.com/job/folder1/job/subfolder/job/jobname\" \"\""
    echo ""
    echo "4. With custom .netrc file:"
    echo "   $0 \"https://jenkins.example.com\" \"folder/jobname\" \"/path/to/custom.netrc\""
    echo ""
    echo "5. Full URL with custom .netrc file:"
    echo "   $0 \"https://jenkins.example.com/job/folder/job/jobname\" \"\" \"/path/to/custom.netrc\""
    echo ""
    echo "6. Public Jenkins (no authentication needed):"
    echo "   $0 \"https://ci.jenkins.io\" \"job-name\""
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
if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

# Handle different argument patterns
if [ $# -eq 1 ] && [[ "$1" == *"/job/"* ]]; then
    # Single argument that's a full job URL
    get_jenkins_builds "" "$1" ""
elif [ $# -eq 1 ]; then
    # Single argument that's not a full URL - need more info
    show_usage
    exit 1
elif [ $# -eq 2 ]; then
    # Two arguments: jenkins_url job_name
    get_jenkins_builds "$1" "$2" ""
elif [ $# -eq 3 ]; then
    # Three arguments: jenkins_url job_name netrc_file
    get_jenkins_builds "$1" "$2" "$3"
else
    # Too many arguments
    echo "Error: Too many arguments provided"
    show_usage
    exit 1
fi
