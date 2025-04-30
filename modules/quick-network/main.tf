terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
locals {
  networks = var.networks
}


resource "libvirt_network" "network" {
  for_each = local.networks

  name      = each.value.kvm_network_name
  mode      = each.value.mode
  autostart = each.value.autostart
  addresses = ["${each.value.gateway4}/${each.value.mask}"]

  domain = each.value.mode == "nat" ? each.value.domain : null
  bridge = each.value.mode == "bridge" ? each.value.bridge : null
}


