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

