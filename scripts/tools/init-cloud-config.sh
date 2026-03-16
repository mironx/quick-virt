#!/bin/bash
#
# Script Name: init-cloud-config.sh
#
# Description:
#   Creates a template cloud-init user-data file in the specified directory.
#   Automatically injects the current user's SSH public key if available.
#   Compatible with Ubuntu, Debian, Rocky Linux, and other cloud-init distros.
#
# Usage:
#   ./init-cloud-config.sh <target_dir>
#   ./init-cloud-config.sh .                          # current directory
#   ./init-cloud-config.sh ./my-project/templates
#
# Output:
#   <target_dir>/user-data.tmpl
#

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target_dir>"
  echo "  Creates a cloud-init user-data template in the target directory."
  exit 1
fi

TARGET_DIR="$1"
OUTPUT_FILE="$TARGET_DIR/user-data.tmpl"

if [[ -f "$OUTPUT_FILE" ]]; then
  echo "[skip] $OUTPUT_FILE already exists"
  exit 0
fi

# Find SSH public key
SSH_KEY=""
for key_file in ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub; do
  if [[ -f "$key_file" ]]; then
    SSH_KEY=$(cat "$key_file")
    echo "[info] Using SSH key: $key_file"
    break
  fi
done

if [[ -z "$SSH_KEY" ]]; then
  echo "[warn] No SSH public key found in ~/.ssh/ — template will have a placeholder"
  SSH_KEY="ssh-rsa YOUR_PUBLIC_KEY_HERE"
fi

mkdir -p "$TARGET_DIR"

cat > "$OUTPUT_FILE" << TMPL
#cloud-config
hostname: HOST_NAME

users:
  - name: \${user_name}
    groups: sudo, wheel
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh-authorized-keys:
      - ${SSH_KEY}
    plain_text_passwd: '\${user_password}'

ssh_pwauth: true

packages:
  - qemu-guest-agent
  - tilde

runcmd:
  - systemctl enable --now qemu-guest-agent
TMPL

echo "[ok] Created: $OUTPUT_FILE"