#!/bin/bash
#
# Script Name: check-shared-folders-drivers.sh
#
# Description:
#   Checks availability of virtiofs and 9p drivers for shared folders.
#   With "install" argument, installs virtiofsd.
#
# Usage:
#   ./check-shared-folders-drivers.sh           # check only
#   ./check-shared-folders-drivers.sh install    # install virtiofsd
#

set -euo pipefail

if [[ "${1:-}" == "install" ]]; then
  echo "Installing virtiofsd..."
  sudo apt install -y virtiofsd
  echo ""
  echo "virtiofsd installed successfully"
  VIRTIOFSD=$(find /usr/libexec /usr/lib/qemu -name virtiofsd 2>/dev/null | head -1)
  if [[ -n "$VIRTIOFSD" ]]; then
    "$VIRTIOFSD" --version 2>/dev/null || true
  fi
  exit 0
fi

echo "=== virtiofsd ==="
VIRTIOFSD=$(find /usr/libexec /usr/lib/qemu -name virtiofsd 2>/dev/null | head -1)
if [[ -n "$VIRTIOFSD" ]]; then
  echo "  found: $VIRTIOFSD"
  "$VIRTIOFSD" --version 2>/dev/null || true
else
  echo "  not found — install with: task setup:install-virtiofsd"
fi

echo ""
echo "=== libvirt filesystem support ==="
virsh domcapabilities 2>/dev/null | grep -A10 filesystem || echo "  cannot check — is libvirtd running?"

echo ""
echo "=== libvirt and QEMU versions ==="
virsh version 2>/dev/null || true

echo ""
echo "=== 9p kernel modules ==="
echo -n "  9p: "
if lsmod | grep -q "^9p "; then
  echo "loaded"
elif modinfo 9p >/dev/null 2>&1; then
  echo "available (not loaded)"
else
  echo "not available"
fi

echo -n "  9pnet_virtio: "
if lsmod | grep -q "^9pnet_virtio "; then
  echo "loaded"
elif modinfo 9pnet_virtio >/dev/null 2>&1; then
  echo "available (not loaded)"
else
  echo "not available"
fi