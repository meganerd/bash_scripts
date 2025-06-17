#!/bin/bash
# flac2mp3_wrapper.sh
# A wrapper script for flac2mp3.sh that creates a mirror directory structure
# with -mp3 appended to the directory names.
# Directories containing MP3 files will be skipped.
#
# Usage: flac2mp3_wrapper.sh <input_dir> [<output_base_dir>]
#
# If output_base_dir is not specified, it will use the same parent directory
# as input_dir and append -mp3 to the input directory name.

# Check if flac2mp3.sh exists and is executable
FLAC2MP3_SCRIPT="$(dirname "$0")/flac2mp3.sh"
if [ ! -x "$FLAC2MP3_SCRIPT" ]; then
    echo "ERROR: flac2mp3.sh not found or not executable at $FLAC2MP3_SCRIPT" >&2
    exit 1
fi

# Function to display usage information
usage() {
    echo "Usage: $(basename "$0") <input_dir> [<output_base_dir>]"
    echo ""
    echo "Parameters:"
    echo "  <input_dir>        Directory tree containing FLAC files"
    echo "  <output_base_dir>  Optional: Base directory for the mirrored structure"
    echo "                     Default: Same parent directory as input_dir"
    echo ""
    echo "Notes:"
    echo "  - Directories containing MP3 files will be skipped"
    echo ""
    echo "Example:"
    echo "  $(basename "$0") /music/flac"
    echo "  This will create /music/flac-mp3 with converted MP3 files"
    echo ""
    echo "  $(basename "$0") /music/flac /backup"
    echo "  This will create /backup/flac-mp3 with converted MP3 files"
    exit 1
}

# Check if at least one argument is provided
if [ $# -lt 1 ]; then
    usage
fi

# Get the input directory and make sure it exists
INPUT_DIR="$1"
if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory '$INPUT_DIR' does not exist" >&2
    exit 1
fi

# Get absolute path of input directory
INPUT_DIR=$(cd "$INPUT_DIR" && pwd)

# Determine the output directory
if [ $# -ge 2 ]; then
    # User specified an output base directory
    OUTPUT_BASE_DIR="$2"
    if [ ! -d "$OUTPUT_BASE_DIR" ]; then
        echo "ERROR: Output base directory '$OUTPUT_BASE_DIR' does not exist" >&2
        exit 1
    fi
    
    # Get absolute path of output base directory
    OUTPUT_BASE_DIR=$(cd "$OUTPUT_BASE_DIR" && pwd)
    
    # Extract the basename of the input directory and append -mp3
    INPUT_BASENAME=$(basename "$INPUT_DIR")
    OUTPUT_DIR="$OUTPUT_BASE_DIR/$INPUT_BASENAME-mp3"
else
    # Default: Use the same parent directory as input_dir
    OUTPUT_DIR="${INPUT_DIR}-mp3"
fi

echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "ERROR: Failed to create output directory '$OUTPUT_DIR'" >&2
    exit 1
fi

# Find all subdirectories in the input directory
echo "Creating mirror directory structure..."
find "$INPUT_DIR" -type d | while read -r dir; do
    # Get the relative path from the input directory
    rel_path="${dir#$INPUT_DIR/}"
    
    # Skip the root directory
    if [ "$rel_path" = "$INPUT_DIR" ] || [ -z "$rel_path" ]; then
        continue
    fi
    
    # Create the corresponding directory in the output structure
    mirror_dir="$OUTPUT_DIR/$rel_path"
    mkdir -p "$mirror_dir"
    echo "Created directory: $mirror_dir"
done

# Process each subdirectory with FLAC files
echo "Processing FLAC files..."
find "$INPUT_DIR" -type d | while read -r dir; do
    # Check if this directory contains any MP3 files - if so, skip it
    if ls "$dir"/*.mp3 >/dev/null 2>&1; then
        echo "Skipping directory with MP3 files: $dir"
        continue
    fi
    
    # Check if this directory contains any FLAC files
    if ls "$dir"/*.flac >/dev/null 2>&1; then
        # Get the relative path from the input directory
        rel_path="${dir#$INPUT_DIR/}"
        
        # Determine the corresponding output directory
        if [ -z "$rel_path" ]; then
            # This is the root input directory
            output_subdir="$OUTPUT_DIR"
        else
            # This is a subdirectory
            output_subdir="$OUTPUT_DIR/$rel_path"
        fi
        
        echo "Converting FLAC files in: $dir"
        echo "Output directory: $output_subdir"
        
        # Call flac2mp3.sh to convert the files
        "$FLAC2MP3_SCRIPT" --in "$dir" --out "$output_subdir"
        
        # Check the return code
        if [ $? -ne 0 ]; then
            echo "WARNING: flac2mp3.sh reported an error for directory: $dir" >&2
        fi
    fi
done

echo "Conversion complete!"
echo "MP3 files are available in: $OUTPUT_DIR"
exit 0
