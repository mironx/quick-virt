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

provider "libvirt" {
  uri = "qemu:///system"
}

module "kvm-networks" {
  source = "../../modules/quick-network"
  networks = local.networks
}