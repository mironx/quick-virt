#!/bin/bash

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
