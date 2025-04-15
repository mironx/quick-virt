#!/bin/bash

set -euo pipefail

echo "🧹 Cleaning up all libvirt VMs and related resources..."

# Destroy and undefine all VMs (running or not)
for vm in $(virsh list --all --name); do
  if [[ -n "$vm" ]]; then
    echo "🛑 Destroying VM: $vm"
    virsh destroy "$vm" 2>/dev/null || true

    echo "❌ Undefining VM: $vm"
    virsh undefine "$vm" --remove-all-storage || virsh undefine "$vm"
  fi
done

# Catch VMs by UUID that may be invisible by name
for uuid in $(virsh list --uuid --all); do
  name=$(virsh domname "$uuid" 2>/dev/null || true)
  if [[ -n "$name" ]]; then
    echo "❌ Undefining hidden VM (UUID: $uuid, Name: $name)"
    virsh destroy "$name" 2>/dev/null || true
    virsh undefine "$name" --remove-all-storage || virsh undefine "$name"
  fi
done

# Remove leftover VM definition XMLs
echo "🗑 Removing orphaned domain XMLs..."
sudo find /etc/libvirt/qemu/ -name '*.xml' -exec sudo rm -v {} \;

# Remove qcow2/iso disks
echo "🗑 Removing images from /var/lib/libvirt/images/..."
sudo find /var/lib/libvirt/images/ -type f \( -name '*.qcow2' -o -name '*.iso' \) -exec sudo rm -v {} \;

echo "✅ Cleanup complete."
