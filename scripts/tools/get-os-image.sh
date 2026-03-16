#!/bin/bash
#
# Script Name: get-os-image.sh
#
# Description:
#   Downloads cloud images for supported OS profiles and places them
#   into the default libvirt image directory. Skips if already exists.
#
# Usage:
#   ./get-os-image.sh <os_name>
#   ./get-os-image.sh list
#   ./get-os-image.sh all
#   ./get-os-image.sh remove <os_name|all>
#
# Supported os_name: ubuntu_22, ubuntu_24, rocky_9, debian_12
#

set -euo pipefail

TARGET_DIR="/var/lib/libvirt/images"

declare -A IMAGE_URLS=(
  [ubuntu_22]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  [ubuntu_24]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  [rocky_9]="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  [debian_12]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
)

declare -A IMAGE_FILES=(
  [ubuntu_22]="ubuntu-2204.qcow2.base"
  [ubuntu_24]="ubuntu-2404.qcow2.base"
  [rocky_9]="rocky-9.qcow2.base"
  [debian_12]="debian-12.qcow2.base"
)

ALL_OS_NAMES=(ubuntu_22 ubuntu_24 rocky_9 debian_12)

download_image() {
  local os_name="$1"
  local url="${IMAGE_URLS[$os_name]}"
  local file="${IMAGE_FILES[$os_name]}"
  local target="$TARGET_DIR/$file"

  if [[ -f "$target" ]]; then
    echo "[ok] $os_name — already exists: $target"
    return 0
  fi

  echo "[downloading] $os_name — $url"
  wget -q --show-progress -O "/tmp/$file" "$url"

  echo "[installing] $os_name — moving to $target"
  sudo mv "/tmp/$file" "$target"
  sudo chown libvirt-qemu:kvm "$target"
  sudo chmod 660 "$target"

  echo "[ok] $os_name — ready: $target"
}

remove_image() {
  local os_name="$1"
  local file="${IMAGE_FILES[$os_name]}"
  local target="$TARGET_DIR/$file"

  if [[ -f "$target" ]]; then
    echo "[removing] $os_name — $target"
    sudo rm -f "$target"
    echo "[ok] $os_name — removed"
  else
    echo "[skip] $os_name — not found"
  fi
}

list_images() {
  echo "OS images in $TARGET_DIR:"
  echo ""
  printf "  %-14s %-35s %s\n" "OS_NAME" "FILE" "STATUS"
  printf "  %-14s %-35s %s\n" "-------" "----" "------"
  for os_name in "${ALL_OS_NAMES[@]}"; do
    local file="${IMAGE_FILES[$os_name]}"
    local target="$TARGET_DIR/$file"
    if [[ -f "$target" ]]; then
      local size
      size=$(du -h "$target" 2>/dev/null | awk '{print $1}')
      printf "  %-14s %-35s %s\n" "$os_name" "$file" "downloaded ($size)"
    else
      printf "  %-14s %-35s %s\n" "$os_name" "$file" "not downloaded"
    fi
  done
}

usage() {
  echo "Usage:"
  echo "  $0 <os_name>           Download a specific image"
  echo "  $0 all                 Download all images"
  echo "  $0 list                List downloaded images"
  echo "  $0 remove <os_name>   Remove a specific image"
  echo "  $0 remove all          Remove all images"
  echo ""
  echo "Supported os_name: ${ALL_OS_NAMES[*]}"
}

# --- Main ---

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

ACTION="$1"

case "$ACTION" in
  list)
    list_images
    ;;
  all)
    for os_name in "${ALL_OS_NAMES[@]}"; do
      download_image "$os_name"
    done
    ;;
  remove)
    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 remove <os_name|all>"
      exit 1
    fi
    TARGET="$2"
    if [[ "$TARGET" == "all" ]]; then
      for os_name in "${ALL_OS_NAMES[@]}"; do
        remove_image "$os_name"
      done
    elif [[ -n "${IMAGE_FILES[$TARGET]+x}" ]]; then
      remove_image "$TARGET"
    else
      echo "Unknown os_name: $TARGET"
      echo "Supported: ${ALL_OS_NAMES[*]}"
      exit 1
    fi
    ;;
  *)
    if [[ -n "${IMAGE_FILES[$ACTION]+x}" ]]; then
      download_image "$ACTION"
    else
      echo "Unknown command or os_name: $ACTION"
      usage
      exit 1
    fi
    ;;
esac