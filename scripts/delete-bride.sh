#!/bin/bash
#
# Simple script to delete a network bridge in Linux
# Usage: ./delete-bridge.sh <bridge_name>
# Example: ./delete-bridge.sh br0

# Check if we have correct number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <bridge_name>"
    echo "Example: $0 br0"
    exit 1
fi

# Get parameters
BRIDGE_NAME=$1

# Check if NetworkManager is running
if systemctl is-active --quiet NetworkManager; then
    echo "Using NetworkManager to delete bridge"

    # Check if bridge exists
    if ! nmcli connection show | grep -q "^$BRIDGE_NAME "; then
        echo "Bridge $BRIDGE_NAME does not exist."
        exit 1
    fi

    # Find all slave interfaces connected to this bridge
    SLAVES=$(nmcli connection show | grep bridge-slave | grep "$BRIDGE_NAME" | awk '{print $1}')

    # Deactivate bridge before deletion
    echo "Deactivating bridge $BRIDGE_NAME..."
    nmcli con down "$BRIDGE_NAME"

    # Delete all slave connections
    for SLAVE in $SLAVES; do
        echo "Deleting slave connection $SLAVE..."
        nmcli con down "$SLAVE" 2>/dev/null
        nmcli con delete "$SLAVE"
    done

    # Delete the bridge connection
    echo "Deleting bridge connection $BRIDGE_NAME..."
    nmcli con delete "$BRIDGE_NAME"

    # Extract physical interface name from slave connections
    PHYSICAL_INTERFACES=""
    for SLAVE in $SLAVES; do
        # Typical format is interface-bridge
        IFACE=$(echo $SLAVE | cut -d'-' -f1)
        if [ -n "$IFACE" ]; then
            PHYSICAL_INTERFACES="$PHYSICAL_INTERFACES $IFACE"
        fi
    done

    # Check if we need to reconnect physical interfaces
    if [ -n "$PHYSICAL_INTERFACES" ]; then
        for IFACE in $PHYSICAL_INTERFACES; do
            echo "Checking for existing connections for interface $IFACE..."

            # Look for existing connection profiles for this interface
            EXISTING_CONN=$(nmcli -g NAME con show | grep -v "bridge\|virbr" | grep "$IFACE" | head -1)

            if [ -n "$EXISTING_CONN" ]; then
                echo "Found existing connection $EXISTING_CONN for $IFACE, activating..."
                nmcli con up "$EXISTING_CONN" || true
            else
                echo "No existing connection found for $IFACE, creating a new one with DHCP..."
                nmcli con add type ethernet con-name "$IFACE" ifname "$IFACE" ipv4.method auto
                nmcli con up "$IFACE" || true
            fi
        done
    fi
else
    echo "NetworkManager not running, using traditional method"

    # Check if bridge exists
    if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
        echo "Bridge $BRIDGE_NAME does not exist."
        exit 1
    fi

    # Find attached interfaces
    INTERFACES=$(ip link show | grep "master $BRIDGE_NAME" | cut -d: -f2 | tr -d ' ')

    # Release DHCP lease if dhclient is running
    if pgrep -f "dhclient $BRIDGE_NAME" > /dev/null; then
        echo "Releasing DHCP lease..."
        dhclient -r $BRIDGE_NAME
    fi

    # Detach interfaces from bridge
    for IFACE in $INTERFACES; do
        echo "Detaching $IFACE from bridge $BRIDGE_NAME..."
        ip link set $IFACE nomaster
    done

    # Delete bridge
    echo "Deleting bridge $BRIDGE_NAME..."
    ip link set dev $BRIDGE_NAME down
    ip link delete $BRIDGE_NAME type bridge

    # Bring interfaces back up and try to get DHCP address
    for IFACE in $INTERFACES; do
        echo "Bringing up interface $IFACE..."
        ip link set dev $IFACE up
        echo "Getting IP address via DHCP for $IFACE..."
        dhclient $IFACE
    done
fi

echo "Bridge $BRIDGE_NAME successfully deleted"