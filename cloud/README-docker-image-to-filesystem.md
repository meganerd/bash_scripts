# Docker Image to Filesystem Converter

This script converts a Docker image into a mountable filesystem image (.img) that contains the complete container filesystem as it would exist at runtime.

## Purpose

The script creates a single ext4 filesystem image from a Docker image by:
1. Pulling the specified Docker image
2. Creating a temporary container from the image
3. Exporting the container's filesystem to a tar archive
4. Creating an ext4 filesystem image with enough space for the files
5. Mounting the image and copying all files to it
6. Producing a mountable .img file

The resulting .img file can be mounted directly in Linux using:
```bash
sudo mount -o loop <image_file>.img /mnt
```

## Requirements

- Docker
- mkfs.ext4 (usually part of e2fsprogs package)
- sudo access (for mounting the filesystem image)
- Optional: fuse2fs (for userspace mounting without sudo)

## Usage

```bash
./docker-image-to-filesystem.sh [--platform PLATFORM] [-o OUTPUT_FILE] IMAGE_NAME
```

### Options

- `--platform PLATFORM`: Specify the platform (default: linux/amd64)
- `-o OUTPUT_FILE`: Output file name (default: IMAGE_NAME.img with special characters replaced by underscores)
- `IMAGE_NAME`: Docker image name (required)

### Examples

```bash
# Convert Alpine Linux image
./docker-image-to-filesystem.sh alpine:3.12

# Convert Ubuntu image with custom output name
./docker-image-to-filesystem.sh -o ubuntu.img ubuntu:20.04

# Convert ARM64 image
./docker-image-to-filesystem.sh --platform linux/arm64 alpine:latest
```

## How It Works

1. **Image Pulling**: The script pulls the specified Docker image if it's not already present locally.

2. **Container Creation**: A temporary container is created from the image to access its filesystem.

3. **Filesystem Export**: The container's filesystem is exported to a tar archive using `docker export`.

4. **Filesystem Extraction**: The tar archive is extracted to a temporary directory, excluding special filesystem directories like `/proc`, `/dev`, etc.

5. **Image Creation**: An ext4 filesystem image is created with sufficient space (with 20% extra) to hold all files.

6. **File Copying**: The extracted files are copied to the mounted filesystem image.

7. **Cleanup**: Temporary files and containers are cleaned up, leaving only the final .img file.

## Mounting the Resulting Image

The resulting .img file can be mounted on any Linux system with root access:

```bash
# Create a mount point
sudo mkdir -p /mnt/docker-image

# Mount the image
sudo mount -o loop <image_file>.img /mnt/docker-image

# Explore the filesystem
ls -la /mnt/docker-image

# Unmount when done
sudo umount /mnt/docker-image
```

## Limitations

1. **Root Privileges**: Mounting the filesystem image requires root privileges (or fuse2fs for userspace mounting).

2. **Size Estimation**: The script estimates the required size by calculating the extracted filesystem size plus 20% padding, with a minimum of 100MB.

3. **Platform Specific**: The script respects Docker platform specifications but the resulting image will be architecture-specific.

## Troubleshooting

### "fuse2fs not found" Warning

This is just a warning. The script will fall back to using `sudo mount` which requires root privileges.

### Permission Denied Errors

Ensure you have sudo access and that the script can execute sudo commands without password prompts for mounting operations.

### Insufficient Space

If you get errors about insufficient space, the automatic size calculation may have been too conservative. You can modify the script to increase the padding percentage.