terraform {
 required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

locals {
  local_network_name = "local-network"
  local_network_addresses = ["192.168.100.0/24"]
}

resource "libvirt_network" "local-network" {
  name      =  local.local_network_name
  mode      = "nat"
  domain    = "local"
  addresses = local.local_network_addresses
  autostart = true
}