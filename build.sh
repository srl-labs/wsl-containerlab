#!/bin/bash

# Define container name and image tag
CONTAINER_NAME="wsl_export"
IMAGE_TAG="ghcr.io/kaelemc/clab-wsl-debian"
EXPORT_FILENAME="clab.wsl" # Keep the filename consistent for now

# --- Automatic Temporary Path Detection ---
TEMP_PATH=""

# Check for WSL-specific temp paths first
if [ -d "/mnt/c/temp" ]; then
    TEMP_PATH="/mnt/c/temp"
    echo "Detected WSL environment. Using temporary path: $TEMP_PATH"
elif [ -d "/mnt/c/Temp" ]; then
    TEMP_PATH="/mnt/c/Temp"
    echo "Detected WSL environment. Using temporary path: $TEMP_PATH"
# If WSL paths don't exist, check for standard Linux /tmp
elif [ -d "/tmp" ]; then
    TEMP_PATH="/tmp"
    echo "Assuming standard Linux environment. Using temporary path: $TEMP_PATH"
else
    # Error if no suitable temp directory is found
    echo "Error: Could not find a suitable temporary directory."
    echo "Checked: /mnt/c/temp, /mnt/c/Temp, /tmp"
    exit 1
fi

# Construct the full path for the export file
EXPORT_FILE_PATH="$TEMP_PATH/$EXPORT_FILENAME"
OLD_EXPORT_FILE_PATH="$EXPORT_FILE_PATH.old"

# --- Docker Operations ---

# Remove the previous container if it exists (ignore errors if it doesn't)
echo "Attempting to remove previous container '$CONTAINER_NAME'..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Build the Docker image
echo "Building Docker image '$IMAGE_TAG'..."
docker build . --tag "$IMAGE_TAG"
if [ $? -ne 0 ]; then
    echo "Error: Docker build failed."
    exit 1
fi

# Rename old export file if it exists
if [ -f "$EXPORT_FILE_PATH" ]; then
    echo "Moving existing '$EXPORT_FILE_PATH' to '$OLD_EXPORT_FILE_PATH'..."
    mv "$EXPORT_FILE_PATH" "$OLD_EXPORT_FILE_PATH"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to move existing export file."
        # Decide if this should be a fatal error or just a warning
    fi
fi

# Run the Docker container (just to create it, ls / is optional)
# Using --rm might be simpler if you don't need to inspect it after failure
# but the original script uses explicit rm, so keeping that pattern.
echo "Running temporary container '$CONTAINER_NAME' from image '$IMAGE_TAG'..."
docker run -t --name "$CONTAINER_NAME" "$IMAGE_TAG" ls /
if [ $? -ne 0 ]; then
    echo "Error: Failed to run the container '$CONTAINER_NAME'."
    # Optional: Clean up container even on failure
    # docker rm "$CONTAINER_NAME" 2>/dev/null || true
    exit 1
fi

# Export the Docker container
echo "Exporting container '$CONTAINER_NAME' to '$EXPORT_FILE_PATH'..."
docker export "$CONTAINER_NAME" > "$EXPORT_FILE_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Docker export failed."
    # Clean up container even on failure
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    exit 1
fi

# Clean up the Docker container
echo "Cleaning up container '$CONTAINER_NAME'..."
docker rm "$CONTAINER_NAME"
if [ $? -ne 0 ]; then
    echo "Warning: Failed to remove the container '$CONTAINER_NAME' after export."
fi

echo "Script finished successfully. Export saved to '$EXPORT_FILE_PATH'."
exit 0