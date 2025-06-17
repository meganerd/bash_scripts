#!/bin/bash
# Debug wrapper for get-acr-repo-and-tag-parallel.sh
# This script helps identify issues with the ACR repo/tag extraction

# Set strict mode to catch more errors
set -o pipefail

# Print usage information
function print_usage {
    echo "Usage: $0 [options]"
    echo "Required options:"
    echo "  -r, --registry <name>   Specify the ACR registry name"
    echo "  -o, --output <file>     Specify the output file path"
    echo "Optional:"
    echo "  -j, --jobs <number>     Max parallel jobs (default: number of CPU cores)"
    echo "  -t, --test              Run in test mode (simulates ACR commands without actual execution)"
    echo "  -x, --trace             Enable bash trace mode (equivalent to bash -x)"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -h, --help              Show this help message"
    exit 1
}

# Parse command line arguments
TEST_MODE=false
TRACE_MODE=false
VERBOSE=false
REGISTRY_NAME=""
DESTINATION=""
MAX_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--registry)
            REGISTRY_NAME="$2"
            shift 2
            ;;
        -o|--output)
            DESTINATION="$2"
            shift 2
            ;;
        -j|--jobs)
            MAX_JOBS="$2"
            shift 2
            ;;
        -t|--test)
            TEST_MODE=true
            shift
            ;;
        -x|--trace)
            TRACE_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            print_usage
            ;;
    esac
done

# Ensure required arguments are provided
if [ -z "$REGISTRY_NAME" ]; then
    echo "Error: Missing required registry name (--registry)"
    print_usage
fi

if [ -z "$DESTINATION" ]; then
    echo "Error: Missing required output file path (--output)"
    print_usage
fi
SCRIPT_PATH="$(dirname "$0")/get-acr-repo-and-tag-parallel.sh"

echo "======= ACR Script Debug Wrapper ======="
echo "Script path: $SCRIPT_PATH"
echo "Registry: $REGISTRY_NAME"
echo "Destination: $DESTINATION"
echo "Max jobs: $MAX_JOBS"
echo "Test mode: $TEST_MODE"
echo "Trace mode: $TRACE_MODE"
echo "Verbose: $VERBOSE"
echo "========================================"

# Check system prerequisites before executing 
if [ "$TEST_MODE" = false ]; then
    echo "Checking system prerequisites..."
    
    # Check if az CLI is installed
    if ! command -v az &>/dev/null; then
        echo "WARNING: Azure CLI (az) is not installed or not in PATH"
        echo "The script will likely fail unless you use --test mode."
        echo "To install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    else
        # Check Azure CLI version
        echo "Azure CLI version:"
        az --version | head -n 1
        
        # Check if user is logged in
        echo "Checking Azure login status..."
        if ! az account show &>/dev/null; then
            echo "WARNING: Not logged in to Azure. Please run 'az login' first."
            echo "The script will likely fail with authentication errors."
        else
            echo "Azure login status: Logged in"
            echo "Current subscription:"
            az account show --query name -o tsv
        fi
        
        # Check if the registry exists
        echo "Checking if ACR registry '$REGISTRY_NAME' exists..."
        if ! az acr show --name "$REGISTRY_NAME" &>/dev/null; then
            echo "WARNING: Registry '$REGISTRY_NAME' not found or you don't have access to it."
            echo "The script will likely fail with authentication or resource errors."
        else
            echo "Registry '$REGISTRY_NAME' exists and is accessible."
        fi
    fi
fi

# Create stub functions for test mode
if [ "$TEST_MODE" = true ]; then
    echo "Setting up test environment..."
    
    # Create a temporary directory for the test
    TEST_DIR=$(mktemp -d)
    echo "Test directory: $TEST_DIR"
    
    # Create mock repositories with a variety of formats to test handling
    MOCK_REPOS=(
        "repo1" 
        "repo2" 
        "repo3/nested" 
        "frontend" 
        "backend"
        "repo with spaces"
        "very/deeply/nested/repository"
        "special-chars_$%^&"
    )
    
    # Write repos to file
    printf "%s\n" "${MOCK_REPOS[@]}" > "$TEST_DIR/repos.txt"
    
    # Create mock tags for each repository
    for repo in "${MOCK_REPOS[@]}"; do
        # Make a safe filename
        safe_repo="${repo//\//_}"
        safe_repo="${safe_repo// /_}"
        
        # Create different numbers of tags for different repos
        tags=()
        case "$repo" in
            "repo1")
                # Many tags
                for i in $(seq 1 20); do
                    tags+=("v1.$i" "latest-$i" "dev-$i" "$(date +%Y%m%d)-$i")
                done
                ;;
            "repo with spaces")
                # Tags with special characters
                tags=("v1.0" "test tag with spaces" "special:char@tag" "$(date +%Y-%m-%d)")
                ;;
            *)
                # Random number of tags
                for i in $(seq 1 $((RANDOM % 5 + 1))); do
                    tags+=("v1.$i" "latest" "dev-$i" "$(date +%Y%m%d)-$i")
                done
                ;;
        esac
        
        # Create directory and tag file
        mkdir -p "$TEST_DIR/$safe_repo"
        printf "%s\n" "${tags[@]}" > "$TEST_DIR/$safe_repo/tags.txt"
        
        echo "Created mock repository '$repo' with ${#tags[@]} tags"
    done
    
    # Create az function wrapper with more detailed logging
    function az() {
        echo "MOCK AZ CLI: az $*" >&2
        
        if [ "$1" = "acr" ]; then
            if [ "$2" = "login" ]; then
                echo "Mock: Logged in to ACR registry $4"
                return 0
            elif [ "$2" = "repository" ]; then
                if [ "$3" = "list" ]; then
                    echo "Mock: Listing repositories in registry $5" >&2
                    cat "$TEST_DIR/repos.txt"
                    return 0
                elif [ "$3" = "show-tags" ]; then
                    repo="${6//\//_}"
                    repo="${repo// /_}"
                    echo "Mock: Listing tags for repository '$6'" >&2
                    if [ -f "$TEST_DIR/$repo/tags.txt" ]; then
                        cat "$TEST_DIR/$repo/tags.txt"
                        return 0
                    else
                        echo "Error: Repository '$6' not found" >&2
                        return 1
                    fi
                elif [ "$3" = "show" ]; then
                    # Mock the repository show command for image manifest details
                    echo "Mock: Showing repository details for $5" >&2
                    
                    # Extract repo and tag from the --image parameter
                    image="$5"
                    if [[ "$4" == "--image" && -n "$image" ]]; then
                        IFS=':' read -r repo tag <<< "$image"
                        
                        # Generate a deterministic but seemingly random hash based on repo and tag
                        hash=$(echo "$repo:$tag" | md5sum | cut -c1-64)
                        
                        # Generate a timestamp from 1-365 days ago
                        # Using hash to ensure consistent dates for the same repo:tag
                        day_offset=$(( $(echo "$hash" | od -An -N1 -i) % 365 ))
                        timestamp=$(date -d "$day_offset days ago" -u +"%Y-%m-%dT%H:%M:%SZ")
                        
                        # Return mock manifest info as JSON
                        cat << EOJSON
{
  "registry": "mockregistry.azurecr.io",
  "imageName": "$repo:$tag",
  "digest": "sha256:$hash",
  "createdTime": "$timestamp",
  "lastUpdateTime": "$timestamp",
  "architecture": "amd64",
  "os": "linux",
  "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
  "configMediaType": "application/vnd.docker.container.image.v1+json",
  "tags": ["$tag"],
  "repository": "$repo"
}
EOJSON
                        return 0
                    else
                        echo "Error: Invalid --image parameter: $image" >&2
                        return 1
                    fi
                fi
            fi
        elif [ "$1" = "account" ]; then
            if [ "$2" = "show" ]; then
                echo "Mock: Showing account info" >&2
                echo '{"name": "Mock Subscription", "id": "00000000-0000-0000-0000-000000000000"}' 
                return 0
            fi
        elif [ "$1" = "--version" ]; then
            echo "azure-cli (mock) 2.50.0"
            return 0
        fi
        
        echo "Mock: Unsupported az command: az $*" >&2
        return 1
    }
    
    # Export the function to be available to the script
    export -f az
    
    echo "Mock Azure CLI environment ready. Will simulate ACR operations."
fi

# Create temp directory for logs if needed
TEMP_LOG_DIR=$(mktemp -d)
trap "rm -rf $TEMP_LOG_DIR" EXIT

# Set up environment variables for the script
export DEBUG_ACR_SCRIPT=true

# Run the script with appropriate options
if [ "$VERBOSE" = true ]; then
    # Create a wrapper that will capture and display all output
    VERBOSE_LOG="$TEMP_LOG_DIR/verbose_output.log"
    echo "Verbose mode enabled. Output will be captured to $VERBOSE_LOG"
    
    # Run with the appropriate trace setting
    if [ "$TRACE_MODE" = true ]; then
        DEBUG=true bash "$SCRIPT_PATH" "$REGISTRY_NAME" "$DESTINATION" "$MAX_JOBS" 2>&1 | tee "$VERBOSE_LOG"
    else
        bash "$SCRIPT_PATH" "$REGISTRY_NAME" "$DESTINATION" "$MAX_JOBS" 2>&1 | tee "$VERBOSE_LOG"
    fi
else
    # Run without verbose output capture
    if [ "$TRACE_MODE" = true ]; then
        DEBUG=true bash "$SCRIPT_PATH" "$REGISTRY_NAME" "$DESTINATION" "$MAX_JOBS"
    else
        bash "$SCRIPT_PATH" "$REGISTRY_NAME" "$DESTINATION" "$MAX_JOBS"
    fi
fi

# Check the results
echo
echo "======= Result Analysis ======="
echo "Command: $SCRIPT_PATH $REGISTRY_NAME $DESTINATION $MAX_JOBS"
SCRIPT_EXIT_CODE=$?

echo -e "\nExit code: $SCRIPT_EXIT_CODE"
if [ $SCRIPT_EXIT_CODE -ne 0 ]; then
    echo "WARNING: Script exited with non-zero status code!"
fi

if [ -f "$DESTINATION" ]; then
    LINES=$(wc -l < "$DESTINATION")
    SIZE=$(du -h "$DESTINATION" | cut -f1)
    echo "Destination file: $DESTINATION"
    echo "File exists: Yes"
    echo "File size: $SIZE"
    echo "Line count: $LINES"
    
    if [ "$LINES" -gt 0 ]; then
        echo -e "\nSample content (first 5 lines):"
        head -n 5 "$DESTINATION"
        
        echo -e "\nSample content (last 5 lines):"
        tail -n 5 "$DESTINATION"
        
        # Skip header line when counting
        ACTUAL_LINES=$((LINES - 1))
        echo -e "\nTotal entries (excluding header): $ACTUAL_LINES"
        
        echo -e "\nRepository count:"
        tail -n +2 "$DESTINATION" | cut -d, -f1 | sort | uniq | wc -l
        
        echo -e "\nTop 5 repositories by tag count:"
        tail -n +2 "$DESTINATION" | cut -d, -f1 | sort | uniq -c | sort -rn | head -n 5
        
        echo -e "\nUnique image count (repo:tag combinations):"
        tail -n +2 "$DESTINATION" | awk -F, '{print $1":"$2}' | sort | uniq | wc -l
        
        echo -e "\nDate range of images:"
        echo "Oldest:" $(tail -n +2 "$DESTINATION" | cut -d, -f3 | grep -v "^$" | sort | head -n 1)
        echo "Newest:" $(tail -n +2 "$DESTINATION" | cut -d, -f3 | grep -v "^$" | sort | tail -n 1)
        
        echo -e "\nCount of entries with missing data:"
        echo "Missing dates:" $(grep -c "^[^,]*,[^,]*,," "$DESTINATION")
        echo "Missing hashes:" $(grep -c "^[^,]*,[^,]*,[^,]*,$" "$DESTINATION")
    else
        echo "WARNING: Destination file is empty!"
        
        # Additional debugging for empty file case
        echo -e "\nChecking for potential issues:"
        echo "1. Was the repository list retrieved successfully?"
        echo "2. Did tag retrieval succeed for each repository?"
        echo "3. Check script verbose output for error messages"
        
        if [ -d "$TEMP_LOG_DIR" ] && [ "$VERBOSE" = true ] && [ -f "$VERBOSE_LOG" ]; then
            echo -e "\nError lines from verbose log:"
            grep -i "error\|warning\|failed" "$VERBOSE_LOG" | tail -n 10
        fi
    fi
else
    echo "ERROR: Destination file does not exist!"
    echo "Check if the script has permission to write to: $DESTINATION"
    echo "Directory exists: $(if [ -d "$(dirname "$DESTINATION")" ]; then echo "Yes"; else echo "No"; fi)"
    echo "Directory is writable: $(if [ -w "$(dirname "$DESTINATION")" ]; then echo "Yes"; else echo "No"; fi)"
fi
echo "============================"

# Clean up test environment if used
if [ "$TEST_MODE" = true ]; then
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
fi
