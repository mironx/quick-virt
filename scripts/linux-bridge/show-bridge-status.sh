#!/bin/bash
#
# Script Name: show-bridge-status.sh
#
# Description:
#   Displays comprehensive status information about Linux bridge interfaces,
#   including their components, IP addresses, link state, and attached VMs.
#   Provides actionable recommendations when issues are detected.
#
# Usage:
#   ./show-bridge-status.sh [bridge_name]
#
#   If no bridge name is specified, all bridges on the system are shown.
#
# Requirements:
#   - ip, bridge (iproute2) must be installed
#   - Optional: nmcli (NetworkManager), virsh (libvirt) for extended info
#

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

header() {
  echo ""
  echo -e "${BOLD}${CYAN}=== $1 ===${NC}"
}

ok()   { echo -e "  ${GREEN}OK${NC}: $1"; }
warn() { echo -e "  ${YELLOW}WARNING${NC}: $1"; }
err()  { echo -e "  ${RED}ERROR${NC}: $1"; }
info() { echo -e "  $1"; }

show_recommendations() {
  local br="$1"
  local has_issue=false

  header "Recommendations for '$br'"

  # Check link state
  local state
  state=$(ip -o link show "$br" 2>/dev/null | awk '{print $9}')
  if [[ "$state" != "UP" ]]; then
    err "Bridge '$br' is not UP (state: ${state:-UNKNOWN})"
    info "  -> Run: sudo ip link set $br up"
    info "  -> Or if using NetworkManager: sudo nmcli connection up $br"
    has_issue=true
  fi

  # Check carrier
  local carrier
  carrier=$(cat /sys/class/net/"$br"/carrier 2>/dev/null || echo "0")
  if [[ "$carrier" != "1" ]]; then
    err "Bridge '$br' has NO-CARRIER — no active slave interface is linked"
    info "  -> Ensure a physical interface is attached and has link (cable connected)"
    info "  -> Check slaves: bridge link show master $br"
    has_issue=true
  fi

  # Check IPv4
  local ipv4
  ipv4=$(ip -o -4 addr show "$br" 2>/dev/null | awk '{print $4}' || true)
  if [[ -z "$ipv4" ]]; then
    err "Bridge '$br' has no IPv4 address"
    info "  -> If using DHCP: sudo dhclient $br"
    info "  -> If using NetworkManager: sudo nmcli connection modify $br ipv4.method auto && sudo nmcli connection up $br"
    info "  -> If using static IP: sudo ip addr add <ip>/<mask> dev $br"
    has_issue=true
  fi

  # Check slaves
  local slaves
  slaves=$(bridge link show master "$br" 2>/dev/null | awk '{print $2}' | tr -d ':' || true)
  if [[ -z "$slaves" ]]; then
    err "Bridge '$br' has no slave interfaces attached"
    info "  -> Attach a physical interface: sudo nmcli connection add type ethernet con-name ${br}-slave ifname <phys_if> master $br"
    info "  -> Or use ip: sudo ip link set <phys_if> master $br"
    has_issue=true
  fi

  if [[ "$has_issue" == "false" ]]; then
    ok "No issues detected with bridge '$br'"
  fi
}

show_bridge() {
  local br="$1"

  header "Bridge: $br"

  # Basic link info
  info "${BOLD}Link status:${NC}"
  local link_info
  link_info=$(ip -o link show "$br" 2>/dev/null || echo "")
  if [[ -z "$link_info" ]]; then
    err "Interface '$br' not found"
    return
  fi

  local state flags mac mtu
  state=$(echo "$link_info" | awk '{print $9}')
  flags=$(echo "$link_info" | grep -oP '<[^>]+>')
  mac=$(echo "$link_info" | grep -oP 'link/ether \K[^ ]+')
  mtu=$(echo "$link_info" | grep -oP 'mtu \K[0-9]+')

  info "  State:  ${state:-UNKNOWN}"
  info "  Flags:  ${flags:-none}"
  info "  MAC:    ${mac:-unknown}"
  info "  MTU:    ${mtu:-unknown}"

  # IPv4 addresses
  info "${BOLD}IPv4 addresses:${NC}"
  local ipv4_addrs
  ipv4_addrs=$(ip -o -4 addr show "$br" 2>/dev/null | awk '{print $4}' || true)
  if [[ -n "$ipv4_addrs" ]]; then
    while IFS= read -r addr; do
      ok "$addr"
    done <<< "$ipv4_addrs"
  else
    warn "No IPv4 address assigned"
  fi

  # IPv6 addresses
  local ipv6_addrs
  ipv6_addrs=$(ip -o -6 addr show "$br" 2>/dev/null | awk '{print $4}' || true)
  if [[ -n "$ipv6_addrs" ]]; then
    info "${BOLD}IPv6 addresses:${NC}"
    while IFS= read -r addr; do
      info "  $addr"
    done <<< "$ipv6_addrs"
  fi

  # Slave interfaces
  info "${BOLD}Slave interfaces:${NC}"
  local slave_info
  slave_info=$(bridge link show master "$br" 2>/dev/null || true)
  if [[ -n "$slave_info" ]]; then
    while IFS= read -r line; do
      local slave_name slave_state
      slave_name=$(echo "$line" | awk '{print $2}' | tr -d ':')
      slave_state=$(echo "$line" | grep -oP 'state \K\w+' || echo "UNKNOWN")
      local slave_carrier
      slave_carrier=$(cat /sys/class/net/"$slave_name"/carrier 2>/dev/null || echo "0")
      if [[ "$slave_state" == "FORWARDING" && "$slave_carrier" == "1" ]]; then
        ok "$slave_name (state: $slave_state, carrier: UP)"
      elif [[ "$slave_carrier" != "1" ]]; then
        err "$slave_name (state: $slave_state, carrier: DOWN — no cable?)"
      else
        warn "$slave_name (state: $slave_state)"
      fi
    done <<< "$slave_info"
  else
    warn "No slave interfaces"
  fi

  # STP info
  local stp_state
  stp_state=$(cat /sys/class/net/"$br"/bridge/stp_state 2>/dev/null || echo "unknown")
  if [[ "$stp_state" == "1" ]]; then
    info "${BOLD}STP:${NC} enabled"
  elif [[ "$stp_state" == "0" ]]; then
    info "${BOLD}STP:${NC} disabled"
  fi

  # NetworkManager connection info
  if command -v nmcli &>/dev/null; then
    local nm_info
    nm_info=$(nmcli -t -f NAME,DEVICE,STATE connection show 2>/dev/null | grep ":${br}:" || true)
    if [[ -n "$nm_info" ]]; then
      local nm_name nm_state
      nm_name=$(echo "$nm_info" | cut -d: -f1)
      nm_state=$(echo "$nm_info" | cut -d: -f3)
      info "${BOLD}NetworkManager:${NC} connection='$nm_name', state='$nm_state'"
    fi
  fi

  # Libvirt network info
  if command -v virsh &>/dev/null; then
    local virsh_nets
    virsh_nets=$(virsh net-list --name 2>/dev/null | grep -v '^$' || true)
    for net in $virsh_nets; do
      local net_bridge
      net_bridge=$(virsh net-dumpxml "$net" 2>/dev/null | xmllint --xpath "string(//bridge/@name)" - 2>/dev/null || true)
      if [[ "$net_bridge" == "$br" ]]; then
        info "${BOLD}Libvirt network:${NC} '$net' uses this bridge"
      fi
    done

    # VMs using this bridge
    local vms_on_bridge
    vms_on_bridge=$(virsh list --name 2>/dev/null | grep -v '^$' || true)
    local found_vm=false
    for vm in $vms_on_bridge; do
      local vm_xml
      vm_xml=$(virsh dumpxml "$vm" 2>/dev/null || true)
      if echo "$vm_xml" | grep -q "bridge='$br'" 2>/dev/null; then
        if [[ "$found_vm" == "false" ]]; then
          info "${BOLD}VMs attached:${NC}"
          found_vm=true
        fi
        info "  - $vm"
      fi
    done
  fi

  show_recommendations "$br"
}

# Main
if [[ $# -eq 1 ]]; then
  BRIDGES="$1"
else
  BRIDGES=$(ls /sys/class/net/*/bridge/bridge_id 2>/dev/null | cut -d/ -f5 || true)
  if [[ -z "$BRIDGES" ]]; then
    echo "No bridge interfaces found on this system."
    echo ""
    echo "To create a bridge, run:"
    echo "  ./create-bridge.sh --phys-if <interface> --bridge-name br0"
    exit 0
  fi
fi

for br in $BRIDGES; do
  show_bridge "$br"
done

echo ""