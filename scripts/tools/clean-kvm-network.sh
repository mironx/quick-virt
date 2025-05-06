#!/bin/bash
#
# Script Name: clean-kvm-network.sh
#
# Description:
#   This script removes specific KVM (libvirt) virtual networks from the system.
#   It destroys and undefines the networks named `local-network` and `bridge-network`,
#   then deletes their corresponding XML configuration files from the libvirt network directory.
#   Finally, it lists all remaining libvirt networks.
#
# Behavior:
#   1. Lists all defined KVM/libvirt networks before cleanup.
#   2. Destroys the `local-network` and `bridge-network` networks if they are running.
#   3. Undefines both networks from libvirt.
#   4. Removes their XML configuration files from `/var/lib/libvirt/network/`.
#   5. Lists all defined networks after cleanup.
#
# Commands Used:
#   - virsh net-list --all
#   - virsh net-destroy <network>
#   - virsh net-undefine <network>
#   - sudo rm -f /var/lib/libvirt/network/<network>.xml
#
# Requirements:
#   - libvirt and virsh must be installed and configured.
#   - The user must have sufficient privileges (typically run as root or via sudo).
#
# Example Usage:
#   ./clean-kvm-network.sh
#
# Note:
#   This script permanently removes the specified virtual networks and their configurations.
#   Use with caution, especially if other virtual machines depend on those networks.
#

virsh net-list --all

virsh net-destroy local-network
virsh net-undefine local-network
virsh net-destroy bridge-network
virsh net-undefine bridge-network
sudo rm -f /var/lib/libvirt/network/local-network.xml
sudo rm -f /var/lib/libvirt/network/bridge-network.xml

virsh net-list --all
