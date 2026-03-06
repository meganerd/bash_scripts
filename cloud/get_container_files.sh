#!/bin/bash

# Quick Container Filesystem Access
# Get files from container without running it

if [ $# -lt 1 ]; then
    echo "Usage: $0 <image_name> [path_to_copy] [local_destination]"
    echo
    echo "Examples:"
    echo "  $0 ubuntu:latest /etc ./container_etc"
    echo "  $0 nginx:latest /usr/share/nginx/html ./nginx_html"
    echo "  $0 alpine:latest /bin ./alpine_bin"
    echo
    exit 1
fi

IMAGE_NAME="$1"
CONTAINER_PATH="${2:-/}"
LOCAL_DEST="${3:-./container_files}"

echo "🔍 Accessing $IMAGE_NAME filesystem without running..."
echo

# Create unique container name
CONTAINER_NAME="temp_examine_$(date +%s)_$$"

echo "📦 Creating stopped container: $CONTAINER_NAME"
if docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "✓ Container created successfully"
else
    echo "❌ Failed to create container from $IMAGE_NAME"
    echo "Make sure the image exists: docker images | grep $(echo "$IMAGE_NAME" | cut -d: -f1)"
    exit 1
fi

echo
echo "📂 Copying $CONTAINER_PATH to $LOCAL_DEST"

if docker cp "$CONTAINER_NAME:$CONTAINER_PATH" "$LOCAL_DEST" 2>/dev/null; then
    echo "✓ Files copied successfully"
    echo
    echo "📁 Contents of $LOCAL_DEST:"
    if [ -d "$LOCAL_DEST" ]; then
        find "$LOCAL_DEST" -maxdepth 1 -ls | head -15
        echo
        echo "Total size:"
        du -sh "$LOCAL_DEST"
    elif [ -f "$LOCAL_DEST" ]; then
        echo "File size: $(find "$LOCAL_DEST" -maxdepth 0 -printf '%s\n' | numfmt --to=iec 2>/dev/null || stat --printf='%s' "$LOCAL_DEST")"
        echo "File type: $(file "$LOCAL_DEST")"
    fi
else
    echo "❌ Failed to copy $CONTAINER_PATH"
    echo "Path may not exist in container"
fi

echo
echo "🧹 Cleaning up container: $CONTAINER_NAME"
docker rm "$CONTAINER_NAME" >/dev/null 2>&1
echo "✓ Cleanup complete"

echo
echo "💡 Pro tip: You can now examine the files in $LOCAL_DEST"
