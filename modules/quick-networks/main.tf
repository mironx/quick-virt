terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
  }
}
locals {
  networks = var.networks
}


resource "libvirt_network" "network" {
  for_each = local.networks

  name      = each.value.kvm_network_name
  autostart = each.value.autostart

  forward = {
    mode = each.value.mode
  }

  ips = each.value.mode != "bridge" ? [{
    address = each.value.gateway4
    prefix  = tonumber(each.value.mask)
  }] : null

  domain = each.value.mode == "nat" && try(each.value.domain, null) != null ? {
    name = each.value.domain
  } : null

  bridge = each.value.mode == "bridge" && try(each.value.bridge, null) != null ? {
    name = each.value.bridge
  } : null
}