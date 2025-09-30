#!/bin/bash

# Extract Docker Image Layers - macOS Compatible Version
# Access the raw filesystem layers of a Docker image
#
# Uses print functions from bashmultitool v2.1-2
# https://github.com/gavinlyonsrepo/bashmultitool

# === BASHMULTITOOL PRINT FUNCTIONS (integrated) ===
# These functions provide colored terminal output

# Internal function for printing text in various modes and colors
# Usage: bmtPrintFunc <mode_color> <text>
# mode_color examples: "norm", "b_red", "b_green", "b_yellow"
function bmtPrintFunc()
{
    local -r normal=$(printf "\033[0m") # Text Reset
    local modeVar=""  # hold the mode
    local colorVar="" # hold the color
    local printVar=""

    # Normal text with reset
    if [ "$1" = "norm" ]
    then
        printf '%s\n' "${normal}$2"
        return 0
    fi

    # check for  "_" i.e. for regular text mode
    if [[ "$1" != *"_"* ]]; then
        modeVar="n" #r for regular
        colorVar="$1"
    else
        local strVar="$1"
        # Extract from this string using parameter expansion
        modeVar=${strVar%_*} # Retain before the colon for code
        colorVar=${strVar##*_} # retain after the colon for colour
    fi

    # Get mode
    case $modeVar in
        n)  modeVar="\033[0;3";; # normal
        b)  modeVar="\033[1;3";; # Bold
        u)  modeVar="\033[4;3";; # Underline
        bg) modeVar="\033[4";; # background
        i)  modeVar="\033[0;9";; # high intensity
        bh)  modeVar="\033[1;9";; # high intensity bold
        hbg)  modeVar="\033[0;10";; # High intensity backgrounds
        *) # Catch user typos
            printf '%s\n'  "1 Error: Unknown keyword $1 : bashmultitool: bmtPrint: bmtPrintFunc"
            return 255
        ;;
    esac

    # get colour
    case $colorVar in
        black)colorVar="0m";;
        red)colorVar="1m";;
        green)colorVar="2m";;
        yellow)colorVar="3m";;
        blue)colorVar="4m";;
        purple)colorVar="5m";;
        cyan)colorVar="6m";;
        white)colorVar="7m";;
        *) # Catch user typos
            printf '%s\n'  "Error: Unknown keyword $1 : bashmultitool: bmtPrint: bmtPrintFunc"
            return 255
        ;;
    esac

    # add mode + color strings and print text
    #if no text don't print Carriage return or reset for just color change
    printVar=$(printf "%s""$modeVar$colorVar")
    if [ -n "$2" ]
    then
        printf '%s\n' "${printVar}$2${normal}"
    else
        printf '%s' "${printVar}$2"
    fi
    return 0
}

# Convenience functions for easier usage
PrintInfo() {
    bmtPrintFunc norm "$1"
}

PrintError() {
    bmtPrintFunc b_red "$1"
}

PrintSuccess() {
    bmtPrintFunc b_green "$1"
}

PrintWarning() {
    bmtPrintFunc b_yellow "$1"
}

# Function to check if we're on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Function to find layer files - macOS compatible
find_layer_files() {
    # Use find instead of glob expansion for better cross-platform compatibility
    find . -name "layer.tar" -type f 2>/dev/null | sort
}

# Function to find OCI format layer files
find_oci_layer_files() {
    # Look for layer files in the blobs directory structure
    find . -path "./blobs/sha256/*" -type f 2>/dev/null | sort
}

# Function to extract image name components - macOS compatible
parse_image_name() {
    local image_name="$1"
    local image_base image_tag

    # Use parameter expansion instead of cut for better compatibility
    if [[ "$image_name" == *:* ]]; then
        image_base="${image_name%:*}"  # Remove :tag from end
        image_tag="${image_name##*:}"  # Remove everything before :
    else
        image_base="$image_name"
        image_tag="latest"
    fi

    # Replace / with _ in image name for safe directory names
    image_base="${image_base//\//_}"

    echo "$image_base" "$image_tag"
}

# Only run main logic when script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Default values
    INTERACTIVE_MODE=false
    EXTRACT_ALL_LAYERS=true
    NO_MERGE=false
    CLEANUP_TAR=false
    SHOW_HELP=false
    PLATFORM_MODE=false
    SPECIFIC_PLATFORM=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            --extract-all)
                EXTRACT_ALL_LAYERS=true
                shift
                ;;
            --cleanup)
                CLEANUP_TAR=true
                shift
                ;;
            --no-merge)
                NO_MERGE=true
                EXTRACT_ALL_LAYERS=false
                shift
                ;;
            -p|--platform)
                PLATFORM_MODE=true
                if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
                    SPECIFIC_PLATFORM="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            *)
                if [ -z "$IMAGE_NAME" ]; then
                    IMAGE_NAME="$1"
                elif [ -z "$OUTPUT_DIR" ]; then
                    OUTPUT_DIR="$1"
                else
                    PrintError "Too many arguments"
                    echo "Usage: $0 [OPTIONS] <image_name> [output_directory]"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Show help if requested or if no image name provided
    if [ "$SHOW_HELP" = true ] || [ -z "$IMAGE_NAME" ]; then
        echo "Usage: $0 [OPTIONS] <image_name> [output_directory]"
        echo
        echo "Extract Docker Image Layers (macOS/Linux Compatible)"
        echo "Access the raw filesystem layers of a Docker image"
        echo
        echo "Arguments:"
        echo "  image_name        Docker image name to extract (format: name:tag)"
        echo "  output_directory  Output directory (default: ./<image-name>_<tag>_layers)"
        echo
        echo "Options:"
        echo "  -h, --help           Show this help message"
        echo "  -i, --interactive    Enable interactive mode"
        echo "  -p, --platform [arch] Extract specific platform (default: all platforms)"
        echo "  --extract-all        Extract all layers into merged filesystem"
        echo "  --cleanup            Remove image.tar after extraction"
        echo
        echo "Examples:"
        echo "  $0 ubuntu:20.04"
        echo "  $0 -i myapp:latest /tmp/extracted"
        echo "  $0 --no-merge nginx:alpine"
        echo "  $0 -p linux/amd64 myapp:latest"
        echo
        echo "By default, the script runs non-interactively and creates a merged folder"
        echo "with the pattern: image-name_image-tag_merged"
        echo
        echo "To disable merged folder creation, use --no-merge"
        echo "To extract specific platform, use -p or --platform"
        echo
        if is_macos; then
            echo "macOS compatibility mode enabled"
        fi
        echo
        exit 0
    fi

    # If in interactive mode, ask for options
    if [ "$INTERACTIVE_MODE" = true ]; then
        read -p "Skip creating merged filesystem view? (y/n): " skip_merge
        if [ "$skip_merge" = "y" ]; then
            EXTRACT_ALL_LAYERS=false
        fi

        read -p "Extract specific platform? (y/n): " platform_choice
        if [ "$platform_choice" = "y" ]; then
            read -p "Enter platform (e.g., linux/amd64, linux/arm64): " SPECIFIC_PLATFORM
            PLATFORM_MODE=true
        fi

        read -p "Remove image.tar to save space? (y/n): " cleanup
        if [ "$cleanup" = "y" ]; then
            CLEANUP_TAR=true
        fi
    fi

    # Generate default output directory name based on image name
    if [ -z "$OUTPUT_DIR" ]; then
        # Use the new parsing function
        read -r SAFE_IMAGE_NAME IMAGE_TAG <<< "$(parse_image_name "$IMAGE_NAME")"
        OUTPUT_DIR="./${SAFE_IMAGE_NAME}_${IMAGE_TAG}_layers"
    fi

    PrintInfo "Extracting layers from $IMAGE_NAME"
    if is_macos; then
        PrintInfo "Running in macOS compatibility mode"
    fi

    # Handle platform-specific extraction
    if [ "$PLATFORM_MODE" = true ]; then
        if [ -n "$SPECIFIC_PLATFORM" ]; then
            PrintInfo "Extracting specific platform: $SPECIFIC_PLATFORM"
            # Create platform-specific output directory
            PLATFORM_SAFE="${SPECIFIC_PLATFORM//\//_}"  # Replace / with _
            PLATFORM_OUTPUT_DIR="${OUTPUT_DIR}_${PLATFORM_SAFE}"
            mkdir -p "$PLATFORM_OUTPUT_DIR"
            cd "$PLATFORM_OUTPUT_DIR" || exit 1

            # Save platform-specific image
            if docker save --platform "$SPECIFIC_PLATFORM" "$IMAGE_NAME" -o image.tar; then
                PrintSuccess "Platform-specific image saved to image.tar"
            else
                PrintError "Failed to save platform-specific image"
                exit 1
            fi
        else
            # Extract all platforms if jq is available
            if command -v jq >/dev/null 2>&1; then
                PrintInfo "Getting platform information from manifest..."
                MANIFEST_OUTPUT=$(docker manifest inspect "$IMAGE_NAME" 2>/dev/null)

                if [ $? -eq 0 ] && [ -n "$MANIFEST_OUTPUT" ]; then
                    # More robust platform extraction
                    PLATFORMS=$(echo "$MANIFEST_OUTPUT" | jq -r '.manifests[]?.platform | select(. != null) | .os + "/" + .architecture' 2>/dev/null | sort -u)

                    if [ -n "$PLATFORMS" ]; then
                        PrintInfo "Found platforms:"
                        echo "$PLATFORMS"

                        # Process each platform - fixed for macOS compatibility
                        ORIGINAL_DIR=$(pwd)
                        echo "$PLATFORMS" | while IFS= read -r PLATFORM; do
                            if [ -n "$PLATFORM" ]; then
                                PrintInfo "Extracting platform: $PLATFORM"
                                PLATFORM_SAFE="${PLATFORM//\//_}"  # Replace / with _
                                PLATFORM_OUTPUT_DIR="${OUTPUT_DIR}_${PLATFORM_SAFE}"
                                mkdir -p "$PLATFORM_OUTPUT_DIR"
                                cd "$PLATFORM_OUTPUT_DIR" || continue

                                # Save platform-specific image
                                if docker save --platform "$PLATFORM" "$IMAGE_NAME" -o image.tar; then
                                    PrintSuccess "Platform $PLATFORM saved to image.tar"
                                    # Extract the tar file with explicit options for macOS
                                    if is_macos; then
                                        gtar -xf image.tar 2>/dev/null || tar -xf image.tar
                                    else
                                        tar -xf image.tar
                                    fi

                                    if [ $? -eq 0 ]; then
                                        PrintSuccess "Image extracted for platform $PLATFORM"
                                        # Process layers for this platform
                                        # Note: We can't call process_layers_and_merge here due to subshell limitations
                                        # Instead, we'll do the processing inline

                                        # Show structure
                                        PrintInfo "Image structure:"
                                        ls -la | grep -E "(json|tar)" || true

                                        PrintInfo "Layer information:"
                                        if [ -f "manifest.json" ]; then
                                            PrintInfo "Found manifest.json - modern image format"
                                            cat manifest.json | python3 -m json.tool 2>/dev/null || cat manifest.json || true
                                        fi

                                        PrintInfo "Available layers:"
                                        LAYER_COUNT=0
                                        # Find layer files using the compatible function
                                        LAYER_FILES=$(find_layer_files)
                                        while IFS= read -r layer_file; do
                                                    if [ -f "$layer_file" ]; then
                                                        LAYER_COUNT=$((LAYER_COUNT + 1))

                                                        # For OCI format, the layer_file is the full path to the blob
                                                        # For traditional format, it's layer.tar in a directory
                                                        if [[ "$layer_file" == ./blobs/sha256/* ]]; then
                                                            layer_name=$(basename "$layer_file")
                                                            PrintInfo "OCI Layer $LAYER_COUNT: $layer_name"
                                                        else
                                                            layer_dir=$(dirname "$layer_file")
                                                            PrintInfo "Layer $LAYER_COUNT: $layer_dir"
                                                        fi

                                                        # Show what's in this layer
                                                        PrintInfo "  Contents preview:"
                                                        if is_macos; then
                                                            tar -tf "$layer_file" 2>/dev/null | head -10 | sed 's/^/    /' || true
                                                        else
                                                            tar -tf "$layer_file" 2>/dev/null | head -10 | sed 's/^/    /'
                                                        fi
                                                        echo
                                                    fi
                                                done <<< "$LAYER_FILES"

                                        # Extract all layers into merged filesystem
                                        if [ "$EXTRACT_ALL_LAYERS" = true ]; then
                                            echo
                                            PrintInfo "Creating merged filesystem view..."

                                            # Generate merged directory name
                                            read -r SAFE_IMAGE_BASE IMAGE_TAG <<< "$(parse_image_name "$IMAGE_NAME")"
                                            MERGED_DIR="${SAFE_IMAGE_BASE}_${IMAGE_TAG}_${PLATFORM_SAFE}_merged"
                                            mkdir -p "$MERGED_DIR"

                                            # Extract all layers in order
                                            while IFS= read -r layer_file; do
                                                if [ -f "$layer_file" ]; then
                                                    if [[ "$layer_file" == ./blobs/sha256/* ]]; then
                                                        layer_name=$(basename "$layer_file")
                                                        PrintInfo "Extracting OCI layer: $layer_name"
                                                    else
                                                        layer_dir=$(dirname "$layer_file")
                                                        PrintInfo "Extracting layer: $layer_dir"
                                                    fi

                                                    if is_macos && command -v gtar >/dev/null 2>&1; then
                                                        gtar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null || tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
                                                    else
                                                        tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
                                                    fi

                                                    if [ $? -ne 0 ]; then
                                                        PrintWarning "Warning: Failed to extract layer $layer_file"
                                                    fi
                                                fi
                                            done <<< "$LAYER_FILES"

                                            PrintSuccess "Merged filesystem created in: $MERGED_DIR"
                                            echo
                                            PrintInfo "Root filesystem contents:"
                                            ls -la "$MERGED_DIR" || true
                                            echo
                                            PrintInfo "You can now browse the complete container filesystem in:"
                                            echo "   $(pwd)/$MERGED_DIR"
                                        fi
                                    else
                                        PrintError "Failed to extract image tar for platform $PLATFORM"
                                    fi
                                else
                                    PrintError "Failed to save platform $PLATFORM"
                                fi

                                cd "$ORIGINAL_DIR" || exit 1
                            fi
                        done
                        exit 0
                    else
                        PrintWarning "No platforms found in manifest, falling back to default extraction"
                    fi
                else
                    PrintWarning "Could not retrieve manifest information, falling back to default extraction"
                fi
            else
                PrintWarning "jq not found, cannot parse manifest. Falling back to default extraction"
            fi

            # Fallback to default behavior
            mkdir -p "$OUTPUT_DIR"
            cd "$OUTPUT_DIR" || exit 1
        fi
    else
        # Default behavior - no platform specification
        mkdir -p "$OUTPUT_DIR"
        cd "$OUTPUT_DIR" || exit 1

        PrintInfo "Saving image to tar file..."
        if docker save "$IMAGE_NAME" -o image.tar; then
            PrintSuccess "Image saved to image.tar"
        else
            PrintError "Failed to save image"
            exit 1
        fi
    fi

    # Only extract the tar file if we're not in multi-platform mode
    if [ "$PLATFORM_MODE" = false ] || [ -n "$SPECIFIC_PLATFORM" ]; then
        PrintInfo "Extracting image tar..."

        # Use appropriate tar command for the platform
        if is_macos; then
            # Try GNU tar first if available, fall back to BSD tar
            if command -v gtar >/dev/null 2>&1; then
                PrintInfo "Using GNU tar (gtar) for extraction"
                gtar -xf image.tar 2>/dev/null || tar -xf image.tar
            else
                PrintInfo "Using BSD tar for extraction"
                tar -xf image.tar
            fi
        else
            tar -xf image.tar
        fi

        if [ $? -eq 0 ]; then
            PrintSuccess "Image extracted"
        else
            PrintError "Failed to extract image tar"
            exit 1
        fi
    fi

# Function to process layers and create merged filesystem
process_layers_and_merge() {
    local platform_suffix="$1"

    # Show structure
    PrintInfo "Image structure:"
    ls -la | grep -E "(json|tar)"

    PrintInfo "Layer information:"
    if [ -f "manifest.json" ]; then
        PrintInfo "Found manifest.json - modern image format"
        # Try multiple JSON formatters
        if command -v jq >/dev/null 2>&1; then
            cat manifest.json | jq . 2>/dev/null
        elif command -v python3 >/dev/null 2>&1; then
            cat manifest.json | python3 -m json.tool 2>/dev/null
        elif command -v python >/dev/null 2>&1; then
            cat manifest.json | python -m json.tool 2>/dev/null
        else
            cat manifest.json
        fi
    fi

    PrintInfo "Available layers:"
    LAYER_COUNT=0

    # Use the more reliable find_layer_files function
    LAYER_FILES=$(find_layer_files)

    # If no traditional layer.tar files found, check for OCI format
    if [ -z "$LAYER_FILES" ]; then
        PrintInfo "No traditional layer.tar files found, checking for OCI format..."
        LAYER_FILES=$(find_oci_layer_files)

        # If still no layers found, check for alternative structures
        if [ -z "$LAYER_FILES" ]; then
            PrintWarning "No layer files found! Checking for alternative structures..."

            # Check for different possible structures
            PrintInfo "Directory contents:"
            find . -type f -name "*.tar" | head -10 || true

            # Look for layers in different locations
            if find . -name "*.tar" -type f 2>/dev/null | grep -q .; then
                PrintWarning "Found tar files but not in expected layer format"
                find . -name "*.tar" -type f 2>/dev/null | while read -r tar_file; do
                    PrintInfo "Found tar file: $tar_file"
                done
            fi

            return 1
        else
            PrintInfo "Found OCI format layer files"
        fi
    fi

    # Process each layer file
    while IFS= read -r layer_file; do
        if [ -f "$layer_file" ]; then
            LAYER_COUNT=$((LAYER_COUNT + 1))

            # For OCI format, the layer_file is the full path to the blob
            # For traditional format, it's layer.tar in a directory
            if [[ "$layer_file" == ./blobs/sha256/* ]]; then
                layer_name=$(basename "$layer_file")
                PrintInfo "OCI Layer $LAYER_COUNT: $layer_name"
            else
                layer_dir=$(dirname "$layer_file")
                PrintInfo "Layer $LAYER_COUNT: $layer_dir"
            fi

            # Show what's in this layer
            PrintInfo "  Contents preview:"
            if is_macos; then
                tar -tf "$layer_file" 2>/dev/null | head -10 | sed 's/^/    /' || true
            else
                tar -tf "$layer_file" 2>/dev/null | head -10 | sed 's/^/    /'
            fi
            echo
        fi
    done <<< "$LAYER_FILES"

    # Extract all layers into merged filesystem by default
    if [ "$EXTRACT_ALL_LAYERS" = true ] && [ "$LAYER_COUNT" -gt 0 ]; then
        echo
        PrintInfo "Creating merged filesystem view..."

        # Parse image name using the new function
        read -r SAFE_IMAGE_BASE IMAGE_TAG <<< "$(parse_image_name "$IMAGE_NAME")"

        # Add platform suffix if provided
        if [ -n "$platform_suffix" ]; then
            MERGED_DIR="${SAFE_IMAGE_BASE}_${IMAGE_TAG}_${platform_suffix}_merged"
        else
            MERGED_DIR="${SAFE_IMAGE_BASE}_${IMAGE_TAG}_merged"
        fi

        mkdir -p "$MERGED_DIR"

        # Extract all layers in order using the found files
        while IFS= read -r layer_file; do
            if [ -f "$layer_file" ]; then
                # For OCI format, the layer_file is the full path to the blob
                # For traditional format, it's layer.tar in a directory
                if [[ "$layer_file" == ./blobs/sha256/* ]]; then
                    layer_name=$(basename "$layer_file")
                    PrintInfo "Extracting OCI layer: $layer_name"
                else
                    layer_dir=$(dirname "$layer_file")
                    PrintInfo "Extracting layer: $layer_dir"
                fi

                # Use appropriate tar command
                if is_macos && command -v gtar >/dev/null 2>&1; then
                    gtar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null || tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
                else
                    tar -xf "$layer_file" -C "$MERGED_DIR" 2>/dev/null
                fi

                if [ $? -ne 0 ]; then
                    PrintWarning "Warning: Failed to extract layer $layer_file"
                fi
            fi
        done <<< "$LAYER_FILES"

        PrintSuccess "Merged filesystem created in: $MERGED_DIR"
        echo
        PrintInfo "Root filesystem contents:"
        ls -la "$MERGED_DIR" || true
        echo
        PrintInfo "You can now browse the complete container filesystem in:"
        echo "   $(pwd)/$MERGED_DIR"
    elif [ "$LAYER_COUNT" -eq 0 ]; then
        PrintError "No layers found to extract!"
        return 1
    fi
}

# Call the function for non-platform mode or specific platform mode
if [ "$PLATFORM_MODE" = false ] || [ -n "$SPECIFIC_PLATFORM" ]; then
    process_layers_and_merge ""
fi

    # Cleanup option
    if [ "$CLEANUP_TAR" = true ]; then
        rm -f image.tar
        PrintSuccess "image.tar removed"
    fi

    echo
    PrintSuccess "Layer extraction complete!"
    PrintInfo "All files are in: $(pwd)"

    # Show what was created
    if [ "$EXTRACT_ALL_LAYERS" = true ] && [ "$PLATFORM_MODE" = false ]; then
        PrintInfo "Merged filesystem is in: $(pwd)/${MERGED_DIR}"
    fi
fi
