#!/bin/bash

# Remove the previous container if it exists
docker rm wsl_export

# Build the Docker image
docker build . --tag ghcr.io/kaelemc/clab-wsl-debian

# Check and handle /temp and /Temp paths
if [ -d "/mnt/c/temp" ]; then
    TEMP_PATH="/mnt/c/temp"
elif [ -d "/mnt/c/Temp" ]; then
    TEMP_PATH="/mnt/c/Temp"
else
    echo "Error: Neither /mnt/c/temp nor /mnt/c/Temp exists."
    exit 1
fi

# Rename old file if it exists
if [ -f "$TEMP_PATH/clab.wsl" ]; then
    mv "$TEMP_PATH/clab.wsl" "$TEMP_PATH/clab.wsl.old"
fi

# Run the Docker container
docker run -t --name wsl_export ghcr.io/kaelemc/clab-wsl-debian ls /

# Export the Docker container
echo "Copying..."
docker export wsl_export > "$TEMP_PATH/clab.wsl"

# Clean up the Docker container
echo "Cleaning up..."
docker rm wsl_export
