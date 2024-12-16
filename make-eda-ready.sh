#!/usr/bin/env bash
set -e

# Pull the latest WSL kernel image
docker pull ghcr.io/srl-labs/wsl-containerlab/wsl-kernel:latest > /dev/null 2>&1

# Create a temporary container to extract the bzImage
docker create --name wsl-kernel ghcr.io/srl-labs/wsl-containerlab/wsl-kernel:latest sleep infinity > /dev/null 2>&1

# Copy the bzImage to a temporary location inside WSL
TMP_BZIMAGE=$(mktemp)
docker cp wsl-kernel:/bzImage "$TMP_BZIMAGE" > /dev/null 2>&1

# Remove the temporary container
docker rm wsl-kernel > /dev/null 2>&1

# Use PowerShell to detect the Windows user profile directory
WIN_USERPROFILE=$(powershell.exe -NoProfile -Command 'echo $env:USERPROFILE' | tr -d '\r')

if [ -z "$WIN_USERPROFILE" ]; then
    echo "Failed to detect Windows user profile directory."
    echo "Please set the kernel path manually in .wslconfig."
    exit 1
fi

WIN_USERNAME=$(echo "$WIN_USERPROFILE" | sed 's|^C:\\Users\\||')

WSL_KERNELS_DIR="/mnt/c/Users/${WIN_USERNAME}/.wsl-kernels"
mkdir -p "$WSL_KERNELS_DIR"
cp "$TMP_BZIMAGE" "${WSL_KERNELS_DIR}/bzImage"
rm "$TMP_BZIMAGE"

WSL_CONFIG_PATH="/mnt/c/Users/${WIN_USERNAME}/.wslconfig"

# Update or create the .wslconfig file
if [ ! -f "$WSL_CONFIG_PATH" ]; then
    echo "[wsl2]" | sudo tee "$WSL_CONFIG_PATH" > /dev/null
fi

if grep -q '^kernel=' "$WSL_CONFIG_PATH"; then
    sudo sed -i "s|^kernel=.*|kernel=c:\\\\\\\\Users\\\\\\\\${WIN_USERNAME}\\\\\\\\.wsl-kernels\\\\\\\\bzImage|g" "$WSL_CONFIG_PATH"
else
    sudo sed -i "/^\[wsl2\]/a kernel=c:\\\\\\\\Users\\\\\\\\${WIN_USERNAME}\\\\\\\\.wsl-kernels\\\\\\\\bzImage" "$WSL_CONFIG_PATH"
fi

echo "make-eda-ready: Kernel moved to ${WSL_KERNELS_DIR}/bzImage and .wslconfig updated."
echo "Stop the WSL (wsl --shutdown Containerlab) for the new kernel to take effect."
