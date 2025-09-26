#!/bin/bash

# Extract Docker Image Layers
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

# Only run main logic when script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Default values
    INTERACTIVE_MODE=false
    EXTRACT_ALL_LAYERS=true
    NO_MERGE=false
    CLEANUP_TAR=false
    SHOW_HELP=false

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
        echo "Extract Docker Image Layers"
        echo "Access the raw filesystem layers of a Docker image"
        echo
        echo "Arguments:"
        echo "  image_name        Docker image name to extract (format: name:tag)"
        echo "  output_directory  Output directory (default: ./<image-name>_<tag>_layers)"
        echo
        echo "Options:"
        echo "  -h, --help        Show this help message"
        echo "  -i, --interactive Enable interactive mode"
        echo "  --extract-all     Extract all layers into merged filesystem"
        echo "  --cleanup         Remove image.tar after extraction"
        echo
        echo "Examples:"
        echo "  $0 ubuntu:20.04"
        echo "  $0 -i myapp:latest /tmp/extracted"
        echo "  $0 --no-merge nginx:alpine"
        echo
        echo "By default, the script runs non-interactively and creates a merged folder"
        echo "with the pattern: image-name_image-tag_merged"
        echo
        echo "To disable merged folder creation, use --no-merge"
        echo
        exit 0
    fi

    # If in interactive mode, ask for options
    if [ "$INTERACTIVE_MODE" = true ]; then
        read -p "Skip creating merged filesystem view? (y/n): " skip_merge
        if [ "$skip_merge" = "y" ]; then
            EXTRACT_ALL_LAYERS=false
        fi

        read -p "Remove image.tar to save space? (y/n): " cleanup
        if [ "$cleanup" = "y" ]; then
            CLEANUP_TAR=true
        fi
    fi

    # Generate default output directory name based on image name
    if [ -z "$OUTPUT_DIR" ]; then
        # Replace / with _ and : with _ to create a safe directory name
        SAFE_IMAGE_NAME=$(echo "$IMAGE_NAME" | tr '/:' '_')
        OUTPUT_DIR="./${SAFE_IMAGE_NAME}_layers"
    fi

    PrintInfo "Extracting layers from $IMAGE_NAME"

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR" || exit 1

    PrintInfo "Saving image to tar file..."
    if docker save "$IMAGE_NAME" -o image.tar; then
        PrintSuccess "Image saved to image.tar"
    else
        PrintError "Failed to save image"
        exit 1
    fi

    PrintInfo "Extracting image tar..."
    if tar -xf image.tar; then
        PrintSuccess "Image extracted"
    else
        PrintError "Failed to extract image tar"
        exit 1
    fi

    # Show structure
    PrintInfo "Image structure:"
    ls -la | grep -E "(json|tar)"

    PrintInfo "Layer information:"
    if [ -f "manifest.json" ]; then
        PrintInfo "Found manifest.json - modern image format"
        cat manifest.json | python3 -m json.tool 2>/dev/null || cat manifest.json
    fi

    PrintInfo "Available layers:"
    LAYER_COUNT=0
    for layer_tar in */layer.tar; do
        if [ -f "$layer_tar" ]; then
            LAYER_COUNT=$((LAYER_COUNT + 1))
            layer_dir=$(dirname "$layer_tar")
            PrintInfo "Layer $LAYER_COUNT: $layer_dir"

            # Show what's in this layer
            PrintInfo "  Contents preview:"
            tar -tf "$layer_tar" 2>/dev/null | head -10 | sed 's/^/    /'
            echo
        fi
    done

    # Extract all layers into merged filesystem by default
    # Create folder with pattern: image-name_image-tag_merged
    if [ "$EXTRACT_ALL_LAYERS" = true ]; then
        echo
        PrintInfo "Creating merged filesystem view..."

        # Generate merged directory name following pattern: image-name_image-tag_merged
        # Split image name and tag
        case "$IMAGE_NAME" in
            *:*)
                IMAGE_BASE=$(echo "$IMAGE_NAME" | cut -d':' -f1)
                IMAGE_TAG=$(echo "$IMAGE_NAME" | cut -d':' -f2)
                ;;
            *)
                IMAGE_BASE="$IMAGE_NAME"
                IMAGE_TAG="latest"
                ;;
        esac
        # Replace / with _ in image name
        SAFE_IMAGE_BASE=$(echo "$IMAGE_BASE" | tr '/' '_')
        MERGED_DIR="${SAFE_IMAGE_BASE}_${IMAGE_TAG}_merged"
        mkdir -p "$MERGED_DIR"

        # Extract all layers in order
        for layer_tar in */layer.tar; do
            if [ -f "$layer_tar" ]; then
                layer_dir=$(dirname "$layer_tar")
                PrintInfo "Extracting layer: $layer_dir"
                tar -xf "$layer_tar" -C "$MERGED_DIR" 2>/dev/null
            fi
        done

        PrintSuccess "Merged filesystem created in: $MERGED_DIR"
        echo
        PrintInfo "Root filesystem contents:"
        ls -la "$MERGED_DIR"
        echo
        PrintInfo "You can now browse the complete container filesystem in:"
        echo "   $(pwd)/$MERGED_DIR"
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
    if [ "$EXTRACT_ALL_LAYERS" = true ]; then
        PrintInfo "Merged filesystem is in: $(pwd)/${MERGED_DIR}"
    fi
fi
