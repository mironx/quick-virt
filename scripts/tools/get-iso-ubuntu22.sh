#!/bin/bash
#
# Script Name: get-iso-ubuntu22.sh
#
# Description:
#   This script downloads the official Ubuntu 22.04 (Jammy Jellyfish) cloud image
#   in QCOW2 format and places it into the default libvirt image directory.
#   It avoids redundant downloads by checking if the image already exists.
#
# Parameters:
#   (None)
#
# Behavior:
#   1. Checks if the QCOW2 base image file (`ubuntu-2204.qcow2.base`) already exists in `/var/lib/libvirt/images`.
#   2. If not found, downloads the latest Ubuntu 22.04 cloud image from:
#      https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
#   3. Moves the downloaded file to `/var/lib/libvirt/images/` and renames it.
#   4. Sets appropriate ownership and permissions for use with libvirt.
#
# Requirements:
#   - wget
#   - sudo privileges (to move the file and set permissions)
#   - libvirt should be installed and configured
#
# Output:
#   The image will be saved as:
#     /var/lib/libvirt/images/ubuntu-2204.qcow2.base
#
# Example Usage:
#   ./get-iso-ubuntu22.sh
#
# Note:
#   This image is intended for use in cloud environments and includes `cloud-init` by default.
#

set -euo pipefail

IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_NAME="ubuntu-2204.qcow2.base"
TARGET_DIR="/var/lib/libvirt/images"
TARGET_PATH="$TARGET_DIR/$IMAGE_NAME"

echo "🔍 Checking if image already exists..."
if [[ -f "$TARGET_PATH" ]]; then
    echo "✅ Image already exists at $TARGET_PATH"
    exit 0
fi

echo "📥 Downloading Ubuntu 22.04 cloud image..."
wget -O "$IMAGE_NAME" "$IMAGE_URL"

if [[ ! -f "$IMAGE_NAME" ]]; then
    echo "❌ Failed to download the image."
    exit 1
fi

echo "📦 Moving image to $TARGET_DIR..."
sudo mv "$IMAGE_NAME" "$TARGET_PATH"

echo "🔐 Setting correct ownership and permissions..."
sudo chown libvirt-qemu:kvm "$TARGET_PATH"
sudo chmod 660 "$TARGET_PATH"

echo "✅ Done! Image is ready to use:"
echo "$TARGET_PATH"
