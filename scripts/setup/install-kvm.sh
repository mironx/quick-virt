#!/bin/bash
#
# Script Name: install-kvm.sh
#
# Description:
#   This script installs KVM (Kernel-based Virtual Machine) and related packages on a Debian-based system.
#   It also checks if KVM is supported on the system and adds the current user to the necessary groups.
#   Finally, it installs additional packages required for modules like quick-kvm-network-reader.

set -euo pipefail

# The script may run under sudo (task setup:install-kvm) -- SUDO_USER then
# holds the invoking user; fall back to the current user for direct runs.
TARGET_USER="${SUDO_USER:-$(id -un)}"

KVM_PACKAGES=(
  qemu-kvm
  libvirt-daemon-system
  libvirt-clients
  bridge-utils
  virtinst
  cloud-image-utils
  genisoimage
  cloud-init
  net-tools
)

TOOL_PACKAGES=(
  jq
  libxml2-utils
  ipcalc
  cpu-checker
)

echo "========================================="
echo " Quick-Virt: KVM Setup"
echo "========================================="
echo ""
echo "The following KVM packages will be installed:"
printf "  - %s\n" "${KVM_PACKAGES[@]}"
echo ""
echo "The following tool packages will be installed:"
printf "  - %s\n" "${TOOL_PACKAGES[@]}"
echo ""
echo "Additionally:"
echo "  - User '$TARGET_USER' will be added to groups: libvirt, kvm"
echo "  - libvirtd service will be enabled and started"
echo "========================================="
echo ""

# 1. Install KVM and related packages
sudo apt update
sudo apt install -y "${KVM_PACKAGES[@]}"

# 1.1 Optionally install virt-manager desktop app
read -rp "Do you want to install virt-manager desktop app? [y/N]: " INSTALL_VIRTMANAGER
if [[ "${INSTALL_VIRTMANAGER,,}" == "y" ]]; then
  sudo apt install -y virt-manager
  echo "virt-manager installed."
else
  echo "Skipping virt-manager."
fi

# 2. Add the invoking user to libvirt and kvm groups
sudo usermod -aG libvirt,kvm "$TARGET_USER"
echo "User '$TARGET_USER' added to groups: libvirt, kvm."
echo "NOTE: log out and back in (or run 'newgrp libvirt' in your shell) for the group change to take effect."

# 3. Enable and start libvirt service
sudo systemctl enable --now libvirtd

# 4. Install other packages for modules like quick-kvm-network-reader
sudo apt install -y "${TOOL_PACKAGES[@]}"

# 5. Status check
echo ""
echo "========================================="
echo " Status Check"
echo "========================================="
echo ""

echo ">> KVM support:"
if kvm-ok 2>/dev/null; then
  echo "   OK"
else
  echo "   WARNING: kvm-ok not found or KVM not supported"
fi
echo ""

echo ">> Services:"
ALL_OK=true
SERVICES=(libvirtd virtlogd)
for svc in "${SERVICES[@]}"; do
  STATUS=$(systemctl is-active "$svc" 2>/dev/null || true)
  ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || true)
  if [[ "$STATUS" == "active" ]]; then
    echo "   [OK]      $svc ($STATUS, $ENABLED)"
  else
    echo "   [WARNING] $svc ($STATUS, $ENABLED)"
    ALL_OK=false
  fi
done
echo ""

echo ">> User groups:"
echo "   $(groups "$TARGET_USER" 2>/dev/null)"
echo ""

echo ">> Installed packages:"
ALL_PACKAGES=("${KVM_PACKAGES[@]}" "${TOOL_PACKAGES[@]}")
for pkg in "${ALL_PACKAGES[@]}"; do
  if dpkg -l "$pkg" &>/dev/null; then
    echo "   [OK] $pkg"
  else
    echo "   [MISSING] $pkg"
    ALL_OK=false
  fi
done
echo ""

if $ALL_OK; then
  echo "========================================="
  echo " All checks passed. Setup complete!"
  echo "========================================="
else
  echo "========================================="
  echo " WARNING: Some packages are missing!"
  echo "========================================="
fi
