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
  use_network_local  = true
  use_network_bridge = false
}

module "local_network_profile_reader" {
  count            = local.use_network_local ? 1 : 0
  source           = "../../modules/quick-kvm-network-reader"
  kvm_network_name = "qvexample-neta-loc-1"
}

module "bridge_network_profile_reader" {
  count            = local.use_network_bridge ? 1 : 0
  source           = "../../modules/quick-kvm-network-reader"
  kvm_network_name = "qvexample-net-bridge"
}

locals {
  vm_profile = var.vm_profile

  local_network_profile_static  = local.use_network_local ? module.local_network_profile_reader[0].profile : null
  bridge_network_profile_static = local.use_network_bridge ? module.bridge_network_profile_reader[0].profile : null

  local_network_profile_dhcp = local.use_network_local ? {
    kvm_network_name = local.local_network_profile_static.kvm_network_name
    dhcp_mode  = "dhcp"
  } : null

  bridge_network_profile_dhcp = local.use_network_bridge ? {
    kvm_network_name = local.bridge_network_profile_static.kvm_network_name
    dhcp_mode  = "dhcp"
    bridge = local.bridge_network_profile_static.bridge
  } : null

  user = var.user
}

locals {
  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = local.user.name
    user_password  = local.user.password
  })
}


module "vm1" {
  source = "../../modules/quick-vm"
  name = "vt1_static_local_network"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    is_enabled = local.use_network_local
    ip         = local.use_network_local ? "192.168.200.16" : null
    profile    = local.local_network_profile_static
  }
  bridge_network = {
    is_enabled = local.use_network_bridge
    ip         = local.use_network_bridge ? "172.16.0.16" : null
    profile    = local.bridge_network_profile_static
  }
}

module "vm2" {
  source = "../../modules/quick-vm"
  name = "vt2_dhcp_local_network"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    is_enabled = local.use_network_local
    profile    = local.local_network_profile_dhcp
  }
  bridge_network = {
    is_enabled = local.use_network_bridge
    profile    = local.bridge_network_profile_dhcp
  }
}

module "vm3" {
  source = "../../modules/quick-vm"
  name = "vt3_dhcp_local_a"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    is_enabled = local.use_network_local
    profile    = local.local_network_profile_dhcp
  }
  bridge_network = {
    is_enabled = false
  }
}

module "vm4" {
  source = "../../modules/quick-vm"
  name = "vt4_dhcp_bridge_a"
  vm_profile = local.vm_profile
  user_data = local.user_data
  local_network = {
    is_enabled = false
  }
  bridge_network = {
    is_enabled = local.use_network_bridge
    profile    = local.bridge_network_profile_dhcp
  }
}

module "vm5" {
  source = "../../modules/quick-vm"
  name = "vt5_dhcp_local_b"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    is_enabled = local.use_network_local
    profile    = local.local_network_profile_dhcp
  }
}

module "vm6" {
  source = "../../modules/quick-vm"
  name = "vt6_dhcp_bridge_b"
  user_data = local.user_data
  vm_profile = local.vm_profile
  bridge_network = {
    is_enabled = local.use_network_bridge
    profile    = local.bridge_network_profile_dhcp
  }
}

module "vm7" {
  source = "../../modules/quick-vm"
  name = "vt7_profile_name"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    is_enabled   = local.use_network_local
    ip           = "192.168.200.20"
    profile_name = "qvexample-neta-loc-1"
  }
  bridge_network = {
    is_enabled   = local.use_network_bridge
    ip           = "172.16.0.20"
    profile_name = "qvexample-net-bridge"
  }
}