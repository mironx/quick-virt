#!/bin/bash
#
# Script Name: restore-network.sh
#
# Description:
#   This script restores a physical network interface to its default standalone state
#   by removing a previously configured bridge and its associated slave connection.
#   It then recreates a standard DHCP connection on the specified physical interface.
#
# Parameters:
#   --phys-if <physical_interface>   The name of the physical network interface to restore (e.g., enp0s31f6).
#   --bridge-name <bridge_name>      The name of the bridge interface that was previously created (e.g., br0).
#
# Requirements:
#   - NetworkManager and nmcli must be installed and running.
#   - The script must be executed with sufficient privileges (e.g., as root or via sudo).
#
# Example Usage:
#   ./restore-network.sh --phys-if enp0s31f6 --bridge-name br0
#   ./restore-network.sh --phys-if enp0s25 --bridge-name br0
#
# Behavior:
#   1. Validates the existence of the specified physical interface.
#   2. Deletes the bridge slave connection (typically named <bridge_name>-slave).
#   3. Deletes the bridge connection itself.
#   4. Recreates a standard Ethernet DHCP connection for the physical interface.
#   5. Brings the physical interface up using the new connection.
#
# Note:
#   This script will remove the bridge and may temporarily interrupt network connectivity.
#   Use with caution, especially on remote systems.
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
SLAVE_CON="${BRIDGE_NAME}-slave"

# Delete the bridge slave connection
nmcli connection delete "$SLAVE_CON"

# Delete the bridge connection
nmcli connection delete "$BRIDGE_NAME"

# Recreate a basic DHCP connection on the physical interface
nmcli connection add type ethernet con-name "$PHYS_IF" ifname "$PHYS_IF" autoconnect yes

# Bring up the physical interface
nmcli connection up "$PHYS_IF"

echo "Bridge removed and $PHYS_IF restored with DHCP"

