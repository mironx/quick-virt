#!/bin/bash
#
# Script to check if a network bridge is properly configured
# Usage: ./check-bridge.sh <bridge_name>
# Example: ./check-bridge.sh br0

# Check if we have correct number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <bridge_name>"
    echo "Example: $0 br0"
    exit 1
fi

# Get parameters
BRIDGE_NAME=$1
CHECK_FAILED=0

# Function to print colored status
print_status() {
    local status=$1
    local message=$2

    if [ "$status" == "OK" ]; then
        echo -e "\e[32m[OK]\e[0m $message"
    elif [ "$status" == "WARNING" ]; then
        echo -e "\e[33m[WARNING]\e[0m $message"
    else
        echo -e "\e[31m[FAILED]\e[0m $message"
        CHECK_FAILED=1
    fi
}

echo "Checking bridge: $BRIDGE_NAME"
echo "=========================="

# 1. Check if bridge exists
if ip link show "$BRIDGE_NAME" &>/dev/null; then
    print_status "OK" "Bridge exists in system"

    # Get bridge details
    BRIDGE_STATE=$(ip -br link show "$BRIDGE_NAME" | awk '{print $2}')
    BRIDGE_MAC=$(ip link show "$BRIDGE_NAME" | grep -o "link/ether [^ ]*" | cut -d' ' -f2)

    # Check bridge state
    if [[ "$BRIDGE_STATE" == *"UP"* ]]; then
        print_status "OK" "Bridge is UP"
    else
        print_status "FAILED" "Bridge is DOWN"
    fi

    # Get IP address information
    IP_INFO=$(ip -4 addr show "$BRIDGE_NAME" | grep -w inet)
    if [ -n "$IP_INFO" ]; then
        IP_ADDRESS=$(echo "$IP_INFO" | awk '{print $2}')
        print_status "OK" "Bridge has IP address: $IP_ADDRESS"

        # Check if default route exists through this bridge
        if ip route | grep default | grep "$BRIDGE_NAME" &>/dev/null; then
            DEFAULT_GW=$(ip route | grep default | grep "$BRIDGE_NAME" | awk '{print $3}')
            print_status "OK" "Default gateway configured: $DEFAULT_GW"

            # Check connectivity to gateway
            if ping -c 1 -W 2 "$DEFAULT_GW" &>/dev/null; then
                print_status "OK" "Gateway is reachable"
            else
                print_status "WARNING" "Gateway is not reachable"
            fi

            # Check internet connectivity
            if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                print_status "OK" "Internet connectivity is working"
            else
                print_status "WARNING" "No internet connectivity"
            fi

            # Check DNS resolution
            if ping -c 1 -W 2 google.com &>/dev/null; then
                print_status "OK" "DNS resolution is working"
            else
                print_status "WARNING" "DNS resolution not working"
            fi
        else
            print_status "WARNING" "No default route through this bridge"
        fi
    else
        print_status "FAILED" "Bridge has no IP address"
    fi

    # Check for connected interfaces
    INTERFACES=$(ip link show | grep "master $BRIDGE_NAME" | cut -d: -f2 | tr -d ' ')
    if [ -n "$INTERFACES" ]; then
        print_status "OK" "Bridge has connected interfaces:"
        for IFACE in $INTERFACES; do
            IFACE_STATE=$(ip -br link show "$IFACE" | awk '{print $2}')
            if [[ "$IFACE_STATE" == *"UP"* ]]; then
                print_status "OK" "  - $IFACE is UP"
            else
                print_status "FAILED" "  - $IFACE is DOWN"
            fi
        done
    else
        print_status "FAILED" "No interfaces connected to bridge"
    fi

    # If NetworkManager is running, check its configuration
    if systemctl is-active --quiet NetworkManager; then
        if nmcli connection show | grep -q "^$BRIDGE_NAME "; then
            print_status "OK" "NetworkManager has configuration for this bridge"

            # Check if bridge is managed by NetworkManager
            if nmcli device | grep -q "$BRIDGE_NAME.*connected"; then
                print_status "OK" "Bridge is managed by NetworkManager"
            else
                print_status "WARNING" "Bridge exists but not managed by NetworkManager"
            fi

            # Check for slave connections
            SLAVES=$(nmcli connection show | grep bridge-slave | grep "$BRIDGE_NAME" | awk '{print $1}')
            if [ -n "$SLAVES" ]; then
                print_status "OK" "NetworkManager has slave connections configured"
            else
                print_status "WARNING" "No slave connections in NetworkManager"
            fi
        else
            print_status "WARNING" "Bridge exists but not configured in NetworkManager"
        fi
    fi

    # Check for multi-layer issues
    if ip addr | grep -v "$BRIDGE_NAME" | grep -q "inet.*brd"; then
        OTHER_INTERFACES=$(ip addr | grep -v "$BRIDGE_NAME" | grep -v "lo" | grep "inet.*brd" | awk '{print $NF}')
        if [ -n "$OTHER_INTERFACES" ]; then
            print_status "WARNING" "Other interfaces also have IP addresses which might cause routing issues:"
            for IFACE in $OTHER_INTERFACES; do
                IP=$(ip -4 addr show "$IFACE" | grep -w inet | awk '{print $2}')
                print_status "WARNING" "  - $IFACE: $IP"
            done
        fi
    fi

else
    print_status "FAILED" "Bridge $BRIDGE_NAME does not exist"
fi

echo "=========================="
if [ $CHECK_FAILED -eq 0 ]; then
    echo -e "\e[32mFinal result: Bridge $BRIDGE_NAME is properly configured\e[0m"
else
    echo -e "\e[31mFinal result: Bridge $BRIDGE_NAME has configuration issues\e[0m"
    exit 1
fi