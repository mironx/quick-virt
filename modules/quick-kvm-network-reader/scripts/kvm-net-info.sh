#!/bin/bash
#
# Script Name: kvm-net-info.sh
#
# Description:
#   This script retrieves detailed network configuration information for a specified KVM (libvirt) virtual network.
#   It parses libvirt's network XML definition and outputs network details in JSON format.
#   This makes it suitable for integration with tools like Terraform via the `external` data source.
#
# Parameters:
#   - A single argument: the name of the KVM network (e.g., "default")
#     OR
#   - JSON input passed via stdin with the following structure:
#       {
#         "kvm_network_name": "<network_name>"
#       }
#
# Example Usage (CLI):
#   ./kvm-net-info.sh default
#
# Example Usage (Terraform external data source):
#   data "external" "net_info" {
#     program = ["${path.module}/scripts/kvm-net-info.sh"]
#
#     query = {
#       kvm_network_name = var.kvm_network_name
#     }
#   }
#
# Behavior:
#   1. Accepts the network name either as a CLI argument or via JSON stdin.
#   2. Extracts XML configuration for the specified libvirt network using `virsh net-dumpxml`.
#   3. Determines the network mode (e.g., "nat" or "bridge").
#   4. Parses relevant fields using `xmllint` and system tools (`ip`, `ipcalc`).
#   5. Outputs a JSON object with:
#      - mode: Network mode (e.g., nat, bridge)
#      - network: Network address
#      - mask_prefix: Subnet prefix length (e.g., 24)
#      - mask_ip: Subnet mask in dotted-decimal notation
#      - gateway: Gateway IP address
#      - bridge: (only for bridge mode) Name of the bridge interface
#
# Requirements:
#   - virsh (libvirt), jq, xmllint, ipcalc, and ip must be installed
#   - Script must be run with appropriate permissions to access libvirt and network interfaces
#
# Note:
#   In bridge mode, the script inspects the host bridge interface to determine addressing.
#   If the bridge interface does not have an IPv4 address, the script returns a JSON-formatted error.
#

set -euo pipefail

if [ $# -eq 1 ]; then
  NET_NAME="$1"
else
  JSON_INPUT=$(cat)
  if echo "$JSON_INPUT" | jq -e .kvm_network_name > /dev/null; then
    NET_NAME=$(echo "$JSON_INPUT" | jq -r .kvm_network_name)
  else
    echo "Usage: $0 <kvm_network_name> OR pass JSON via stdin" >&2
    exit 1
  fi
fi

XML=$(virsh net-dumpxml "$NET_NAME")

MODE=$(echo "$XML" | xmllint --xpath "string(//forward/@mode)" - 2>/dev/null || echo "")
BRIDGE=$(echo "$XML" | xmllint --xpath "string(//bridge/@name)" -)

if [[ "$MODE" == "nat" ]]; then
  GATEWAY=$(echo "$XML" | xmllint --xpath "string(//ip/@address)" -)
  PREFIX=$(echo "$XML" | xmllint --xpath "string(//ip/@prefix)" -)
  CIDR="$GATEWAY/$PREFIX"
else
  IFACE_INFO=$(ip -o -4 addr show "$BRIDGE" | grep inet || true)
  if [ -z "$IFACE_INFO" ]; then
    echo "{\"error\": \"Bridge interface $BRIDGE has no IPv4 address\"}"
    exit 1
  fi
  CIDR=$(echo "$IFACE_INFO" | awk '{print $4}')
  GATEWAY=$(echo "$CIDR" | cut -d/ -f1)
  PREFIX=$(echo "$CIDR" | cut -d/ -f2)
fi

NETWORK=$(ipcalc "$CIDR" | grep -w "Network" | awk '{print $2}' | cut -d/ -f1)
NETMASK=$(ipcalc "$CIDR" | grep -w "Netmask" | awk '{print $2}')

# Return data as JSON (stdout)
if [[ "$MODE" == "bridge" ]]; then
  echo "{\"mode\": \"$MODE\", \"network\": \"$NETWORK\", \"mask_prefix\": \"$PREFIX\", \"mask_ip\": \"$NETMASK\", \"gateway\": \"$GATEWAY\", \"bridge\": \"$BRIDGE\"}"
else
  echo "{\"mode\": \"$MODE\", \"network\": \"$NETWORK\", \"mask_prefix\": \"$PREFIX\", \"mask_ip\": \"$NETMASK\", \"gateway\": \"$GATEWAY\"}"
fi

