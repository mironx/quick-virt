#!/bin/bash
#
# Description:
#   This script creates a network bridge on a Linux system using NetworkManager's `nmcli` command-line tool.
#   It sets up a new bridge interface and attaches a specified physical interface to it as a slave.
#   The bridge is configured to use the MAC address of the physical interface and is set to obtain
#   its IPv4 address via DHCP while disabling IPv6.
#
# Parameters:
#   --phys-if <physical_interface>   The name of the physical network interface (e.g., enp0s31f6).
#   --bridge-name <bridge_name>      The desired name for the new bridge interface (e.g., br0).
#
# Requirements:
#   - NetworkManager and nmcli must be installed and running.
#   - The script must be executed with sufficient privileges (e.g., as root or via sudo).
#
# Example Usage:
#   ./create-bridge.sh --phys-if enp0s31f6 --bridge-name br0
#   ./create-bridge.sh --phys-if enp0s25 --bridge-name br0
#
# Behavior:
#   1. Validates the existence of the specified physical interface.
#   2. Reads the MAC address from the physical interface.
#   3. Creates a bridge connection using nmcli.
#   4. Sets the bridge's MAC address to match the physical interface.
#   5. Adds the physical interface to the bridge as a slave.
#   6. Configures the bridge to obtain an IP address via DHCP (IPv4 only).
#   7. Brings the bridge interface up.
#
# Note:
#   This script modifies network settings and may disrupt existing network connections during execution.
#

usage() {
  echo "Usage: $0 --phys-if <physical_interface> --bridge-name <bridge_name>"
  exit 1
}

# Parse named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phys-if)
      PHYS_IF="$2"
      shift 2
      ;;
    --bridge-name)
      BRIDGE_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

# Validate required arguments
if [[ -z "$PHYS_IF" || -z "$BRIDGE_NAME" ]]; then
  echo "Error: both --phys-if and --bridge-name are required."
  usage
fi

# Check if physical interface exists
if [[ ! -d "/sys/class/net/$PHYS_IF" ]]; then
  echo "Error: physical interface '$PHYS_IF' does not exist."
  exit 1
fi

# Read MAC address from the physical interface
MAC=$(cat /sys/class/net/$PHYS_IF/address)
echo "MAC address of $PHYS_IF: $MAC"

# Create the bridge connection
nmcli connection add type bridge autoconnect yes con-name "$BRIDGE_NAME" ifname "$BRIDGE_NAME"

# Assign the MAC address to the bridge
nmcli connection modify "$BRIDGE_NAME" 802-3-ethernet.cloned-mac-address "$MAC"

# Add the physical interface as a slave to the bridge
nmcli connection add type ethernet autoconnect yes con-name "${BRIDGE_NAME}-slave" \
  ifname "$PHYS_IF" master "$BRIDGE_NAME"

# Set the bridge to use DHCP for IPv4 and ignore IPv6
nmcli connection modify "$BRIDGE_NAME" ipv4.method auto ipv6.method ignore

# Bring up the bridge
nmcli connection up "$BRIDGE_NAME"
