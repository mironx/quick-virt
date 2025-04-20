#!/bin/bash
#
# Simple script to create a network bridge in Linux
# Usage: ./create-bridge.sh <bridge_name> <physical_interface>
# Example: ./create-bridge.sh br0 enp0s25

# Check if we have correct number of arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <bridge_name> <physical_interface>"
    echo "Example: $0 br0 enp0s25"
    exit 1
fi

# Get parameters
BRIDGE_NAME=$1
PHYSICAL_INTERFACE=$2

# Check if NetworkManager is running
if systemctl is-active --quiet NetworkManager; then
    echo "Using NetworkManager to create bridge"

    # Check if interface exists
    if ! nmcli device | grep -q "$PHYSICAL_INTERFACE"; then
        echo "Error: Interface $PHYSICAL_INTERFACE does not exist."
        echo "Available interfaces:"
        nmcli device | grep -E "ethernet|wifi" | awk '{print $1}'
        exit 1
    fi

    # Check if bridge already exists
    if nmcli connection show | grep -q "^$BRIDGE_NAME "; then
        echo "Bridge $BRIDGE_NAME already exists."
        exit 1
    fi

    # Create bridge connection
    echo "Creating bridge $BRIDGE_NAME..."
    nmcli con add type bridge ifname $BRIDGE_NAME con-name $BRIDGE_NAME

    # Configure bridge to use DHCP
    echo "Configuring bridge to use DHCP..."
    nmcli con modify $BRIDGE_NAME ipv4.method auto

    # Connect physical interface to bridge
    echo "Adding $PHYSICAL_INTERFACE to bridge $BRIDGE_NAME..."
    nmcli con add type bridge-slave ifname $PHYSICAL_INTERFACE master $BRIDGE_NAME con-name ${PHYSICAL_INTERFACE}-${BRIDGE_NAME}

    # Clone MAC address from physical interface
    echo "Cloning MAC address from $PHYSICAL_INTERFACE to $BRIDGE_NAME..."
    MAC=$(nmcli -g GENERAL.HWADDR device show $INTERFACE | tr -d '\\' | tr '[A-Z]' '[a-z]')
    if [ -n "$MAC" ]; then
        nmcli con modify $BRIDGE_NAME 802-3-ethernet.cloned-mac-address "$MAC"
        echo "MAC address set to: $MAC"
    fi

    # Activate the bridge
    echo "Activating bridge $BRIDGE_NAME..."
    nmcli con up $BRIDGE_NAME
else
    echo "NetworkManager not running, using traditional method"

    # Check if interface exists
    if ! ip link show "$PHYSICAL_INTERFACE" &>/dev/null; then
        echo "Error: Interface $PHYSICAL_INTERFACE does not exist."
        echo "Available interfaces:"
        ip link show | grep -v "link/" | grep -v "^ " | cut -d: -f2 | tr -d ' '
        exit 1
    fi

    # Check if bridge-utils is installed
    if ! command -v brctl &> /dev/null; then
        echo "Error: bridge-utils not installed."
        echo "Please install with: sudo apt install bridge-utils"
        exit 1
    fi

    # Create bridge
    echo "Creating bridge $BRIDGE_NAME..."
    ip link add name $BRIDGE_NAME type bridge

    # Set bridge MAC to be the same as the physical interface
    MAC=$(ip link show $PHYSICAL_INTERFACE | grep -o "link/ether [^ ]*" | cut -d' ' -f2)
    if [ -n "$MAC" ]; then
        ip link set dev $BRIDGE_NAME address $MAC
        echo "MAC address set to: $MAC"
    fi

    # Add interface to bridge
    echo "Adding $PHYSICAL_INTERFACE to bridge $BRIDGE_NAME..."
    ip link set $PHYSICAL_INTERFACE master $BRIDGE_NAME

    # Bring up interfaces
    ip link set dev $PHYSICAL_INTERFACE up
    ip link set dev $BRIDGE_NAME up

    # Use DHCP to get an IP address
    echo "Getting IP address via DHCP..."
    dhclient $BRIDGE_NAME
fi

echo "Bridge $BRIDGE_NAME successfully created and connected to $PHYSICAL_INTERFACE"
echo "You can check the status with: ip addr show $BRIDGE_NAME"