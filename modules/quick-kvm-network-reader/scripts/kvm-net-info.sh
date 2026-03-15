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

log() {
  echo "[kvm-net-info] $*" >&2
}

if [ $# -eq 1 ]; then
  NET_NAME="$1"
  log "Invoked as CLI with argument: $NET_NAME"
else
  JSON_INPUT=$(cat)
  log "Invoked via JSON stdin: $JSON_INPUT"
  if echo "$JSON_INPUT" | jq -e .kvm_network_name > /dev/null 2>&1; then
    NET_NAME=$(echo "$JSON_INPUT" | jq -r .kvm_network_name)
    log "Parsed network name: $NET_NAME"
  else
    log "ERROR: Missing 'kvm_network_name' key in JSON input"
    log "Usage: $0 <kvm_network_name> OR pass JSON via stdin with {\"kvm_network_name\": \"...\"}"
    exit 1
  fi
fi

log "Fetching libvirt network XML for '$NET_NAME'..."
if ! XML=$(virsh net-dumpxml "$NET_NAME" 2>&1); then
  log "ERROR: Failed to get network XML for '$NET_NAME'. Is the network defined?"
  log "virsh output: $XML"
  exit 1
fi

MODE=$(echo "$XML" | xmllint --xpath "string(//forward/@mode)" - 2>/dev/null || echo "")
BRIDGE=$(echo "$XML" | xmllint --xpath "string(//bridge/@name)" -)
log "Network '$NET_NAME': mode='$MODE', bridge='$BRIDGE'"

if [[ "$MODE" == "nat" ]]; then
  GATEWAY=$(echo "$XML" | xmllint --xpath "string(//ip/@address)" -)
  PREFIX=$(echo "$XML" | xmllint --xpath "string(//ip/@prefix)" -)
  CIDR="$GATEWAY/$PREFIX"
  log "NAT mode: gateway=$GATEWAY, prefix=$PREFIX"
else
  log "Bridge mode: checking interface '$BRIDGE' for IPv4 address..."
  IFACE_INFO=$(ip -o -4 addr show "$BRIDGE" 2>&1 | grep inet || true)
  if [ -z "$IFACE_INFO" ]; then
    LINK_STATE=$(ip link show "$BRIDGE" 2>&1 || true)
    log "WARNING: Bridge interface '$BRIDGE' has no IPv4 address — returning empty profile"
    log "Interface state: $LINK_STATE"
    log "Hint: Ensure '$BRIDGE' is UP and has an IP assigned (e.g., via DHCP or static config)"
    echo "{\"mode\": \"bridge\", \"network\": \"\", \"mask_prefix\": \"\", \"mask_ip\": \"\", \"gateway\": \"\", \"bridge\": \"$BRIDGE\", \"error\": \"Bridge interface $BRIDGE has no IPv4 address\"}"
    exit 0
  fi
  CIDR=$(echo "$IFACE_INFO" | awk '{print $4}')
  PREFIX=$(echo "$CIDR" | cut -d/ -f2)
  GATEWAY=$(ip route | grep "default.*dev $BRIDGE" | awk '{print $3}' | head -1)
  if [ -z "$GATEWAY" ]; then
    GATEWAY=$(echo "$CIDR" | cut -d/ -f1)
    log "Bridge mode: no default route via $BRIDGE, falling back to interface IP as gateway"
  fi
  log "Bridge mode: cidr=$CIDR, gateway=$GATEWAY, prefix=$PREFIX"
fi

NETWORK=$(ipcalc "$CIDR" | grep -w "Network" | awk '{print $2}' | cut -d/ -f1)
NETMASK=$(ipcalc "$CIDR" | grep -w "Netmask" | awk '{print $2}')
log "Computed: network=$NETWORK, netmask=$NETMASK"

# Return data as JSON (stdout only — all debug goes to stderr)
if [[ "$MODE" == "bridge" ]]; then
  echo "{\"mode\": \"$MODE\", \"network\": \"$NETWORK\", \"mask_prefix\": \"$PREFIX\", \"mask_ip\": \"$NETMASK\", \"gateway\": \"$GATEWAY\", \"bridge\": \"$BRIDGE\", \"error\": \"\"}"
else
  echo "{\"mode\": \"$MODE\", \"network\": \"$NETWORK\", \"mask_prefix\": \"$PREFIX\", \"mask_ip\": \"$NETMASK\", \"gateway\": \"$GATEWAY\", \"error\": \"\"}"
fi