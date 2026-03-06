#!/usr/bin/env bash

# Script to convert a Docker image to a mountable filesystem image
# Usage: docker-image-to-filesystem.sh [--platform PLATFORM] [-o OUTPUT_FILE] IMAGE_NAME
#
# Note: This script uses 'docker export' to get the complete filesystem rather than
# directly accessing individual layer tarballs. This is because:
# 1. Direct access to Docker's internal layer storage requires root privileges
# 2. The overlay filesystem structure is complex and version-dependent
# 3. 'docker export' provides a reliable way to get the final filesystem state
# 4. This approach is similar to how tools like 'docker-diff.sh' work

set -euo pipefail

# Default values
PLATFORM_VALUE="linux/amd64"
OUTPUT_FILE=""
TEMP_DIR=""
CLEANUP=true

# Cleanup function
cleanup() {
    if [ "$CLEANUP" = true ] && [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Print usage
usage() {
    echo "Usage: $0 [--platform PLATFORM] [-o OUTPUT_FILE] IMAGE_NAME"
    echo ""
    echo "Convert a Docker image to a mountable filesystem image using layer tarballs."
    echo ""
    echo "Options:"
    echo "  --platform PLATFORM    Specify the platform (default: linux/amd64)"
    echo "  -o OUTPUT_FILE         Output file name (default: IMAGE_NAME.img)"
    echo ""
    echo "Example: $0 alpine:3.12"
    echo "Example: $0 --platform linux/arm64 -o myimage.img ubuntu:20.04"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            if [ -z "$2" ]; then
                echo "Error: --platform requires a value" >&2
                usage
                exit 1
            fi
            PLATFORM_VALUE="$2"
            shift 2
            ;;
        -o)
            if [ -z "$2" ]; then
                echo "Error: -o requires a value" >&2
                usage
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage
            exit 1
            ;;
        *)
            if [ -z "${IMAGE_NAME:-}" ]; then
                IMAGE_NAME="$1"
            else
                echo "Error: Too many arguments" >&2
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if image name is provided
if [ -z "${IMAGE_NAME:-}" ]; then
    echo "Error: IMAGE_NAME is required" >&2
    usage
    exit 1
fi

# Set default output file if not provided
if [ -z "$OUTPUT_FILE" ]; then
    # Replace special characters in image name with underscores for filename
    SAFE_IMAGE_NAME=$(echo "$IMAGE_NAME" | sed 's/[:\/]/_/g')
    OUTPUT_FILE="${SAFE_IMAGE_NAME}.img"
fi

 # Check if required tools are available
 for tool in docker mkfs.ext4; do
     if ! command -v "$tool" &> /dev/null; then
         echo "Error: Required tool '$tool' is not installed" >&2
         exit 1
     fi
 done

 # Check for fuse2fs, if not available we'll need to use a different approach
 USE_FUSE2FS=true
 if ! command -v fuse2fs &> /dev/null; then
     echo "Warning: fuse2fs not found, will require root privileges to mount filesystem image"
     USE_FUSE2FS=false
 fi

echo "Converting Docker image '$IMAGE_NAME' to filesystem image '$OUTPUT_FILE'..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Pull the image if it doesn't exist locally
echo "Pulling image..."
docker pull --platform "$PLATFORM_VALUE" "$IMAGE_NAME"

# Create a container from the image
echo "Creating temporary container..."
CONTAINER_ID=$(docker create --platform "$PLATFORM_VALUE" "$IMAGE_NAME" /bin/sh)

# Export the container filesystem to tar
# This is the most reliable way to get the complete filesystem without
# needing root access to Docker's internal storage or understanding the
# complex overlay filesystem structure
echo "Exporting container filesystem..."
docker export "$CONTAINER_ID" > "$TEMP_DIR/filesystem.tar"

# Remove the container
docker rm -f "$CONTAINER_ID" > /dev/null 2>&1

# Create a directory to extract files
ROOTFS_DIR="$TEMP_DIR/rootfs"
mkdir -p "$ROOTFS_DIR"

# Extract the filesystem
echo "Extracting filesystem..."
tar -xf "$TEMP_DIR/filesystem.tar" -C "$ROOTFS_DIR" \
    --exclude='./etc/mtab' \
    --exclude='./proc' \
    --exclude='./dev' \
    --exclude='./sys' \
    --exclude='./tmp' \
    --exclude='./run' \
    --exclude='./var/run' \
    --exclude='./var/tmp' \
    --exclude='./var/lock'

# Calculate size needed for the filesystem image
# We'll add 20% extra space to be safe
SIZE_BYTES=$(du -sb "$ROOTFS_DIR" | awk '{print $1}')
SIZE_MB=$(( (SIZE_BYTES * 120) / 1024 / 1024 / 100 ))
# Ensure minimum size of 100MB
if [ "$SIZE_MB" -lt 100 ]; then
    SIZE_MB=100
fi

echo "Creating filesystem image of ${SIZE_MB}MB..."

# Create an empty image file
dd if=/dev/zero of="$OUTPUT_FILE" bs=1M count="$SIZE_MB" status=none

# Create ext4 filesystem on the image
mkfs.ext4 -F "$OUTPUT_FILE" > /dev/null

# Create a temporary mount point
MOUNT_POINT="$TEMP_DIR/mount"
mkdir -p "$MOUNT_POINT"

# Mount the image
echo "Mounting filesystem image..."
if [ "$USE_FUSE2FS" = true ]; then
    if ! fuse2fs -o allow_root "$OUTPUT_FILE" "$MOUNT_POINT"; then
        echo "Error: Failed to mount filesystem image with fuse2fs" >&2
        exit 1
    fi

    # Verify the mount was successful
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo "Error: Mount point $MOUNT_POINT is not a valid mount point" >&2
        exit 1
    fi

    echo "Successfully mounted filesystem image"

    # Set up cleanup to unmount properly
    unmount_image() {
        if mountpoint -q "$MOUNT_POINT"; then
            fusermount -u "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
        fi
    }
else
    # Need root privileges for mount - use sudo
    echo "Mounting filesystem image with sudo..."
    if ! sudo mount -o loop "$OUTPUT_FILE" "$MOUNT_POINT"; then
        echo "Error: Failed to mount filesystem image with sudo" >&2
        echo "Attempting to diagnose the issue..."
        echo "Checking if image file exists: $(ls -la "$OUTPUT_FILE" 2>&1)"
        echo "Checking file type: $(file "$OUTPUT_FILE" 2>&1)"
        exit 1
    fi

    # Verify the mount was successful
    if ! mountpoint -q "$MOUNT_POINT"; then
        echo "Error: Mount point $MOUNT_POINT is not a valid mount point" >&2
        exit 1
    fi

    echo "Successfully mounted filesystem image"

    # Set up cleanup to unmount properly
    unmount_image() {
        if mountpoint -q "$MOUNT_POINT"; then
            sudo umount "$MOUNT_POINT" 2>/dev/null || true
        fi
    }
fi
trap unmount_image EXIT

# Copy files to the mounted filesystem
echo "Copying files to filesystem image..."
if [ "$USE_FUSE2FS" = true ]; then
    cp -a "$ROOTFS_DIR/." "$MOUNT_POINT/"
else
    sudo cp -a "$ROOTFS_DIR/." "$MOUNT_POINT/"
fi

# Unmount the filesystem
unmount_image

echo "Successfully created mountable filesystem image: $OUTPUT_FILE"
if [ "$USE_FUSE2FS" = true ]; then
    echo "You can mount it with: mount -o loop $OUTPUT_FILE /mnt (or use fuse2fs)"
else
    echo "You can mount it with: sudo mount -o loop $OUTPUT_FILE /mnt"
fi
