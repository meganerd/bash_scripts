#!/bin/bash
# Enable trace mode if DEBUG is set
[[ "${DEBUG:-}" == "true" ]] && set -x

# Check if at least 2 arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <registry_name> <destination> [max_parallel_jobs]"
    echo "  max_parallel_jobs: Optional parameter to limit parallel jobs (default: number of CPU cores)"
    exit 1
fi

registry_name="$1"
destination="$2"
max_jobs="${3:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

# Check if az CLI is installed
if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI (az) is not installed or not in PATH"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check Azure CLI version
echo "Azure CLI version:"
az --version | head -n 1

# Check if user is logged in
echo "Checking Azure login status..."
az account show &>/dev/null || {
    echo "ERROR: Not logged in to Azure. Please run 'az login' first."
    exit 1
}

# Log in to ACR
echo "Logging into ACR registry $registry_name..."
az acr login --name "$registry_name" || {
    echo "ERROR: Failed to log in to ACR registry '$registry_name'"
    echo "Please check if the registry exists and you have access to it."
    exit 1
}

# Create or truncate the destination file
echo "Preparing output file $destination..."
# Add CSV header
echo "repository,tag,date,hash" > "$destination"

# Get list of repositories
echo "Fetching repository list..."
repos="$(az acr repository list -n "$registry_name" --output tsv)" || {
    echo "ERROR: Failed to fetch repository list from registry '$registry_name'"
    echo "Please check:"
    echo "  1. Registry name is correct"
    echo "  2. You are logged in to Azure (az login)"
    echo "  3. You have access to the registry"
    exit 1
}

# Check if we got any repositories
if [ -z "$repos" ]; then
    echo "WARNING: No repositories found in registry '$registry_name'"
    exit 0
fi

# Create a temporary directory for parallel processing
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Create a wrapper script for process_repo in the temp directory
cat > "$temp_dir/process_repo.sh" << EOL
#!/bin/bash
# Pass variables explicitly to the script
registry_name="$registry_name"
temp_dir="$temp_dir"

repo="\$1"
# Create a safe filename by replacing both slashes and spaces
safe_repo="\${repo//\//_}"
safe_repo="\${safe_repo// /_}"
temp_file="\$temp_dir/\$safe_repo.txt"
    
echo "Processing repository: \$repo"
# Get tags for the repository with error handling
images="\$(az acr repository show-tags -n "\$registry_name" --repository "\$repo" --output tsv --orderby time_desc)" || {
    echo "ERROR: Failed to fetch tags for repository '\$repo'" >&2
    exit 1
}
    
# Debug info
echo "Found \$(echo "\$images" | wc -w) tags for \$repo" >&2
    
# Process each tag to get date and digest (hash)
for tag in \$images; do
    echo "Processing tag: \$repo:\$tag" >&2
    
    # Get manifest details including digest and creation time
    manifest_info="\$(az acr repository show -n "\$registry_name" --image "\$repo:\$tag" --output json 2>/dev/null)"
    
    if [ -n "\$manifest_info" ]; then
        # Extract digest (hash) - remove 'sha256:' prefix if present
        digest="\$(echo "\$manifest_info" | grep -o '\"digest\":\"[^\"]*\"' | sed 's/\"digest\":\"//g' | sed 's/\"//g' | sed 's/sha256://g')"
        
        # Extract timestamp and convert to ISO format
        timestamp="\$(echo "\$manifest_info" | grep -o '\"lastUpdateTime\":\"[^\"]*\"' | sed 's/\"lastUpdateTime\":\"//g' | sed 's/\"//g')"
        
        # Escape any commas in the repository or tag name to maintain CSV integrity
        safe_repo_csv="\$(echo "\$repo" | sed 's/,/\\,/g')"
        safe_tag_csv="\$(echo "\$tag" | sed 's/,/\\,/g')"
        
        # Write to temp file in CSV format: repository,tag,date,hash
        echo "\$safe_repo_csv,\$safe_tag_csv,\$timestamp,\$digest" >> "\$temp_file"
    else
        echo "WARNING: Could not fetch manifest for \$repo:\$tag" >&2
        # Still include in output but with empty date and hash
        safe_repo_csv="\$(echo "\$repo" | sed 's/,/\\,/g')"
        safe_tag_csv="\$(echo "\$tag" | sed 's/,/\\,/g')"
        echo "\$safe_repo_csv,\$safe_tag_csv,,unknown" >> "\$temp_file"
    fi
done

# Verify file was created and has content
if [ -f "\$temp_file" ]; then
    echo "Created \$temp_file with \$(wc -l < "\$temp_file") entries" >&2
else
    echo "Error: Failed to create \$temp_file" >&2
fi
EOL

chmod +x "$temp_dir/process_repo.sh"

# Add debug header to show what's happening
echo "================================================="
echo "Starting ACR repository and tag collection process"
echo "Registry: $registry_name"
echo "Destination: $destination"
echo "Max parallel jobs: $max_jobs"
echo "Temporary directory: $temp_dir"
echo "================================================="

# Check if GNU parallel is available
if command -v parallel &>/dev/null; then
    echo "Using GNU parallel with $max_jobs parallel jobs..."
    # Use printf and xargs to handle repos with spaces properly
    printf "%s\n" $repos | parallel -j "$max_jobs" "$temp_dir/process_repo.sh"
else
    echo "GNU parallel not found, using background processes with $max_jobs parallel jobs..."
    # Process repositories in parallel using background processes
    count=0
    # Use printf and read to handle repos with spaces properly
    printf "%s\n" $repos | while IFS= read -r repo; do
        echo "Starting process for repository: $repo"
        "$temp_dir/process_repo.sh" "$repo" &
        
        # Limit the number of concurrent background processes
        (( count++ ))
        if (( count >= max_jobs )); then
            echo "Reached max jobs ($max_jobs), waiting for a job to finish..."
            wait -n  # Wait for any job to finish
            (( count-- ))
        fi
    done
    
    # Wait for all remaining background processes to complete
    echo "Waiting for all remaining jobs to complete..."
    wait
fi

# Combine all temp files into the destination file
echo "Combining results into $destination..."
file_count=0
total_lines=0

# Create a list of all result files
echo "Creating list of result files..."
temp_file_list="$temp_dir/file_list.txt"
find "$temp_dir" -type f -name "*.txt" | grep -v "file_list.txt" | sort > "$temp_file_list"
echo "Found $(wc -l < "$temp_file_list") result files"

# Process files one by one to avoid subshell issues
while IFS= read -r file; do
    if [ -s "$file" ]; then
        lines=$(wc -l < "$file")
        echo "Adding $lines lines from: $file"
        cat "$file" >> "$destination"
        file_count=$((file_count + 1))
        total_lines=$((total_lines + lines))
    else
        echo "Warning: Empty file: $file"
    fi
done < "$temp_file_list"

echo "Processed $file_count files with $total_lines total entries"

# Verify the destination file has content
if [ ! -s "$destination" ]; then
    echo "WARNING: The destination file is empty. Check for errors in processing."
    echo "Temp directory contents:"
    ls -la "$temp_dir"
    
    # Check if any repos were processed
    if [ -z "$repos" ]; then
        echo "ERROR: No repositories were fetched from the registry."
        echo "Check that '$registry_name' is a valid registry and you have proper access."
    fi
    
    echo "Debug information:"
    echo "- Registry name: $registry_name"
    echo "- Destination: $destination"
    echo "- Max jobs: $max_jobs"
    echo "- Temp directory: $temp_dir"
    echo "- Repositories found: $(echo "$repos" | wc -w)"
    
    echo "Temp directory file list:"
    find "$temp_dir" -type f | xargs ls -la
fi

echo "Completed! All repositories and tags saved to $destination"
