#!/bin/bash
set -euo pipefail

if [ $# -eq 1 ]; then
  NET_NAME="$1"
else
  # zczytaj stdin do jednej zmiennej
  # read stdin to one variable
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
echo "{\"network\": \"$NETWORK\", \"prefix\": \"$PREFIX\", \"netmask\": \"$NETMASK\", \"gateway\": \"$GATEWAY\", \"bridge\": \"$BRIDGE\"}"

