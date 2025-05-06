#!/bin/bash
#
# Script Name: clean-all-vms.sh
#
# Description:
#   This script performs a full cleanup of all KVM (libvirt) virtual machines and related resources.
#   It forcefully destroys and undefines all VMs (even hidden or inactive ones), removes any leftover
#   VM definition XML files, and deletes associated disk images (e.g., `.qcow2`, `.iso`) from the default storage directory.
#
# Behavior:
#   1. Destroys and undefines all visible VMs using `virsh list --all`.
#   2. Attempts to clean up any VMs that might be hidden or only accessible by UUID.
#   3. Deletes leftover domain XML definitions from `/etc/libvirt/qemu/`.
#   4. Removes VM disk images (e.g., `.qcow2`, `.iso`) from `/var/lib/libvirt/images/`.
#
# Commands Used:
#   - virsh list --all --name
#   - virsh destroy <vm>
#   - virsh undefine <vm> [--remove-all-storage]
#   - virsh list --uuid --all
#   - virsh domname <uuid>
#   - find /etc/libvirt/qemu/ -name '*.xml'
#   - find /var/lib/libvirt/images/ -name '*.qcow2' -o -name '*.iso'
#
# Requirements:
#   - libvirt, virsh, and necessary permissions to access and remove system VM files.
#   - Root privileges for deleting system-wide files (run via sudo or as root).
#
# Example Usage:
#   ./clean-all-vms.sh
#
# Note:
#   ⚠️ This script is destructive. It permanently deletes **all** VMs and their storage.
#   Use with extreme caution, especially in production or shared environments.
#

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
