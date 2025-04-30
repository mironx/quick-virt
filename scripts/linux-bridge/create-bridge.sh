#!/bin/bash

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
