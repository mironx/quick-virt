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
  networks = var.networks
  vm_profile = var.vm_profile
  local_network_profile_static = local.networks["local0"]
  bridge_network_profile_static = local.networks["bridge"]

  local_network_profile_dhcp = {
    kvm_network_name = local.local_network_profile_static.kvm_network_name
    dhcp_mode  = "dhcp"

  }
  bridge_network_profile_dhcp = {
    kvm_network_name = local.bridge_network_profile_static.kvm_network_name
    dhcp_mode  = "dhcp"
    bridge = "br0"
  }

  user = var.user
}

locals {
  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = local.user.name
    user_password  = local.user.password
  })
}


module "vm1" {
  source = "../modules/quick_vm"
  name = "vt1_static_lcoal_network"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    ip         = "192.168.100.16"
    profile = local.local_network_profile_static
  }
  bridge_network = {
    ip         = "172.16.0.16"
    profile = local.bridge_network_profile_static
  }
}

module "vm2" {
  source = "../modules/quick_vm"
  name = "vt2_dhcp_lcoal_network"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    profile = local.local_network_profile_dhcp
  }
  bridge_network = {
    profile = local.bridge_network_profile_dhcp
  }
}

module "vm3" {
  source = "../modules/quick_vm"
  name = "vt3_dhcp_local_a"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    profile = local.local_network_profile_dhcp
  }
  bridge_network = {
    is_enabled = false
  }
}

module "vm4" {
  source = "../modules/quick_vm"
  name = "vt4_dhcp_bridge_a"
  vm_profile = local.vm_profile
  user_data = local.user_data
  local_network = {
    is_enabled = false
  }
  bridge_network = {
    profile = local.bridge_network_profile_dhcp
  }
}

module "vm5" {
  source = "../modules/quick_vm"
  name = "vt5_dhcp_local_b"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    profile = local.local_network_profile_dhcp
  }
}

module "vm6" {
  source = "../modules/quick_vm"
  name = "vt6_dhcp_bridge_b"
  user_data = local.user_data
  vm_profile = local.vm_profile
  bridge_network = {
    profile = local.bridge_network_profile_dhcp
  }
}