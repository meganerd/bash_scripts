#!/bin/bash

# Container Filesystem Explorer - Access container files without running
# Multiple methods to examine container filesystems

echo "=== Container Filesystem Access Methods ==="
echo

# Method 1: Docker cp from stopped container
echo "Method 1: Create stopped container and use docker cp"
echo "=================================================="
echo "# Create container without starting it"
echo "docker create --name temp_container <image_name>"
echo "# Copy files out"
echo "docker cp temp_container:/path/to/file ./local_file"
echo "docker cp temp_container:/app ./local_app_directory"
echo "# Clean up"
echo "docker rm temp_container"
echo

# Method 2: Docker save and extract
echo "Method 2: Export image layers and extract"
echo "========================================"
echo "# Save image to tar"
echo "docker save <image_name> -o image.tar"
echo "# Extract tar"
echo "tar -xf image.tar"
echo "# Each layer is in its own directory with layer.tar"
echo "# Extract specific layer"
echo "cd <layer_hash>"
echo "tar -xf layer.tar"
echo

# Method 3: Access Docker's storage directly
echo "Method 3: Access Docker storage directory (requires root)"
echo "======================================================="
echo "# Find container's filesystem location"
echo "docker inspect <container_name> | grep MergedDir"
echo "# Access files directly (as root)"
echo "sudo ls /var/lib/docker/overlay2/<hash>/merged/"
echo

# Method 4: Use dive tool
echo "Method 4: Use 'dive' tool for layer analysis"
echo "==========================================="
echo "# Install dive"
echo "curl -OL https://github.com/wagoodman/dive/releases/download/v0.10.0/dive_0.10.0_linux_amd64.deb"
echo "sudo dpkg -i dive_0.10.0_linux_amd64.deb"
echo "# Analyze image"
echo "dive <image_name>"
echo

# Method 5: Use skopeo
echo "Method 5: Use skopeo to copy and extract"
echo "======================================="
echo "# Install skopeo"
echo "sudo apt install skopeo"
echo "# Copy image to directory format"
echo "skopeo copy docker://<image_name> dir:./image_dir"
echo "# Extract layers manually"
echo

echo "=== Practical Examples ==="
echo

read -rp "Do you want to see a practical demonstration? (y/n): " demo

if [ "$demo" = "y" ]; then
    echo
    echo "Let's demonstrate with an available image..."
    
    # List available images
    echo "Available Docker images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10
    echo
    
    read -rp "Enter image name to examine (e.g., ubuntu:latest): " image_name
    
    if [ -n "$image_name" ]; then
        echo
        echo "🔍 Examining $image_name without running it..."
        echo
        
        # Method 1 demo
        echo "Method 1: Using docker create + docker cp"
        echo "========================================"
        
        container_name="temp_examine_$(date +%s)"
        
        echo "Creating stopped container: $container_name"
        if docker create --name "$container_name" "$image_name" > /dev/null; then
            echo "✓ Container created successfully"
            echo
            
            echo "Container filesystem root contents:"
            docker cp "$container_name":/ - | tar -tv | head -20
            echo
            
            echo "Example: Copying /etc directory to local machine:"
            docker cp "$container_name":/etc ./container_etc 2>/dev/null
            if [ -d "./container_etc" ]; then
                echo "✓ /etc directory copied to ./container_etc"
                echo "Contents of /etc:"
                find ./container_etc -maxdepth 1 -ls | head -10
                rm -rf ./container_etc
            fi
            
            echo
            echo "Cleaning up container: $container_name"
            docker rm "$container_name" > /dev/null
            echo "✓ Container removed"
        else
            echo "❌ Failed to create container"
        fi
        
        echo
        echo "Method 2: Image layer extraction"
        echo "==============================="
        
        echo "Extracting image layers..."
        temp_dir="/tmp/image_extract_$(date +%s)"
        mkdir -p "$temp_dir"
        
        echo "Saving image to tar file..."
        docker save "$image_name" -o "$temp_dir/image.tar"
        
        echo "Extracting image tar..."
        cd "$temp_dir" || exit
        tar -xf image.tar 2>/dev/null
        
        echo "Image structure:"
        find . -maxdepth 1 \( -name "*.json" -o -name "*.tar" \) -ls
        echo
        
        echo "Layer directories:"
        find . -name "layer.tar" | head -5
        
        # Extract first layer as example
        first_layer=$(find . -name "layer.tar" | head -1)
        if [ -n "$first_layer" ]; then
            layer_dir=$(dirname "$first_layer")
            echo
            echo "Extracting first layer from: $layer_dir"
            cd "$layer_dir" || exit
            tar -tf layer.tar | head -20
        fi
        
        echo
        echo "Cleaning up temporary files..."
        rm -rf "$temp_dir"
        echo "✓ Cleanup complete"
    fi
fi

echo
echo "=== Summary of Methods ==="
echo "========================="
echo "1. docker create + docker cp    - Easiest, no special tools needed"
echo "2. docker save + tar extraction - Access to all layers"
echo "3. Direct storage access        - Requires root, immediate access"
echo "4. dive tool                    - Best for analysis and exploration"
echo "5. skopeo                       - Good for automated extraction"
echo
echo "💡 Recommendation: Use Method 1 (docker create + cp) for most cases"
