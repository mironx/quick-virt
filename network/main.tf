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
  bridge_network_name = "bridge-network"
  bridge_network_interface = "enp0s25"
  bridge_network_addresses = ["172.16.0.0/12"]
  bridge_network_domain = "bridge.local"
}

resource "libvirt_network" "local-network" {
  name      =  local.local_network_name
  mode      = "nat"
  domain    = "local"
  addresses = local.local_network_addresses
  autostart = true
}

resource "libvirt_network" "bridge-network" {
  name      = local.bridge_network_name
  mode      = "bridge"
  bridge    = local.bridge_network_interface
  addresses = local.bridge_network_addresses
  autostart = true
}

