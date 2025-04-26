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
  vm_profile = {
    vcpu = 1
    memory = 2048
    user_name = "devx"
  }
  local_network_profile_static = {
    mask       = "24"
    gateway4 = "192.168.100.1"
    nameservers = ["192.168.100.1"]
    dhcp_mode  = "static"
  }
  bridge_network_profile_static = {
    mask       = "12"
    gateway4 = "172.16.0.1"
    nameservers = ["172.16.0.1"]
    dhcp_mode  = "static"
    bridge = "br0"
  }
  local_network_profile_dhcp = {
    dhcp_mode  = "dhcp"
  }
  bridge_network_profile_dhcp = {
    dhcp_mode  = "dhcp"
    bridge = "br0"
  }
  user_password = trimspace(file("${path.module}/pswd"))
}

locals {
  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_password  = local.user_password
  })
}



module "vm1" {
  source = "../modules/vm_ubuntu_24"
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
  source = "../modules/vm_ubuntu_24"
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
  source = "../modules/vm_ubuntu_24"
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
  source = "../modules/vm_ubuntu_24"
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
  source = "../modules/vm_ubuntu_24"
  name = "vt5_dhcp_local_b"
  user_data = local.user_data
  vm_profile = local.vm_profile
  local_network = {
    profile = local.local_network_profile_dhcp
  }
}

module "vm6" {
  source = "../modules/vm_ubuntu_24"
  name = "vt6_dhcp_bridge_b"
  user_data = local.user_data
  vm_profile = local.vm_profile
  bridge_network = {
    profile = local.bridge_network_profile_dhcp
  }
}