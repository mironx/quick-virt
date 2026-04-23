#!/bin/bash
# Scaffold a Terraform project that provisions KVM networks via the quick-networks module.
#
# Usage: init-networks.sh [DIR] [REF]
#   DIR  target directory (default: current)
#   REF  git ref for the module source (default: content of installer's .version file, else 'main')

set -euo pipefail

DIR="${1:-.}"
REF="${2:-}"

# Resolve module ref from installer's .version (set by install.sh) if not provided.
if [ -z "$REF" ]; then
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    version_file="$script_dir/../../.version"
    if [ -f "$version_file" ]; then
        REF="$(tr -d '[:space:]' < "$version_file")"
    fi
fi
REF="${REF:-main}"

mkdir -p "$DIR"

write_if_missing() {
    local name="$1"
    local path="$DIR/$name"
    if [ -e "$path" ]; then
        printf '[skip] %s (already exists)\n' "$path"
        cat >/dev/null
        return
    fi
    cat > "$path"
    printf '[ok]   %s\n' "$path"
}

write_if_missing "main.tf" <<EOF
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

module "kvm_networks" {
  source   = "git::https://github.com/mironx/quick-virt.git//modules/quick-networks?ref=${REF}"
  networks = var.networks
}
EOF

write_if_missing "variables.tf" <<'EOF'
variable "networks" {
  type = map(object({
    mode             = string
    domain           = optional(string)
    kvm_network_name = string
    mask             = string
    gateway4         = string
    nameservers      = list(string)
    dhcp_mode        = string
    bridge           = optional(string)
    autostart        = bool
  }))
  description = "Map of KVM network profiles."
}
EOF

write_if_missing "networks.auto.tfvars" <<'EOF'
networks = {
  qvexample-neta-loc-1 = {
    kvm_network_name = "qvexample-neta-loc-1"
    mode             = "nat"
    domain           = "la1.local"
    mask             = "24"
    gateway4         = "192.168.200.1"
    nameservers      = ["192.168.200.1"]
    dhcp_mode        = "static"
    autostart        = true
  }

  # A second NAT network — uncomment if you want two independent subnets.
  # qvexample-neta-loc-2 = {
  #   kvm_network_name = "qvexample-neta-loc-2"
  #   mode             = "nat"
  #   domain           = "la2.local"
  #   mask             = "24"
  #   gateway4         = "192.168.201.1"
  #   nameservers      = ["192.168.201.1"]
  #   dhcp_mode        = "static"
  #   autostart        = true
  # }

  # A bridge network — requires a pre-existing Linux bridge on the host.
  # Create one with: task bridge:create PHYS_IF=enp0s31f6 BRIDGE_NAME=br0
  # qvexample-net-bridge = {
  #   kvm_network_name = "qvexample-net-bridge"
  #   mode             = "bridge"
  #   mask             = "12"
  #   gateway4         = "172.16.0.1"
  #   nameservers      = ["172.16.0.1"]
  #   dhcp_mode        = "static"
  #   bridge           = "br0"
  #   autostart        = true
  # }
}
EOF

cat <<EOF

Scaffolded quick-virt network project in: $DIR
Module pinned to ref:                     $REF

Next steps:
  cd $DIR
  terraform init
  terraform apply
EOF