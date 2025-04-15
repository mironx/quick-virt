#!/bin/bash

set -euo pipefail

echo "🔧 Disabling AppArmor profiles for QEMU/libvirt..."

# Make sure AppArmor is installed
if ! command -v aa-status >/dev/null; then
  echo "❌ AppArmor is not installed or not active on this system."
  exit 1
fi

# Create disable links
echo "🔗 Linking profiles to /etc/apparmor.d/disable/..."
sudo mkdir -p /etc/apparmor.d/disable
sudo ln -sf /etc/apparmor.d/libvirt-qemu /etc/apparmor.d/disable/
if [[ -f /etc/apparmor.d/libvirt/TEMPLATE.qemu ]]; then
  sudo ln -sf /etc/apparmor.d/libvirt/TEMPLATE.qemu /etc/apparmor.d/disable/
fi

# Unload profiles immediately
echo "📦 Unloading AppArmor QEMU profiles..."
sudo apparmor_parser -R /etc/apparmor.d/libvirt-qemu || true
sudo apparmor_parser -R /etc/apparmor.d/libvirt/TEMPLATE.qemu || true

# Restart libvirt
echo "🔄 Restarting libvirt daemon..."
sudo systemctl restart libvirtd

echo "✅ AppArmor profiles for QEMU have been disabled."\

echo "chmod 751 /var/lib/libvirt/images"
sudo chmod 751 /var/lib/libvirt/images
