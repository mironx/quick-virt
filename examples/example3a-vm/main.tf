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
  vm_profile = var.vm_profile
  user       = var.user
}

locals {
  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = local.user.name
    user_password = local.user.password
  })
}

# vm1: static IP on both networks
module "vm1" {
  source     = "../../modules/quick-vm"
  name       = "vt1_static_both"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.16" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.16" }
  ]
}

# vm2: DHCP on both networks
module "vm2" {
  source     = "../../modules/quick-vm"
  name       = "vt2_dhcp_both"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-neta-loc-1", profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [], kvm_network_name = "qvexample-neta-loc-1" } },
    { profile_name = "qvexample-net-bridge", profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [], bridge = "br0", kvm_network_name = "qvexample-net-bridge" } }
  ]
}

# vm3: DHCP local only
module "vm3" {
  source     = "../../modules/quick-vm"
  name       = "vt3_dhcp_local_only"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-neta-loc-1", profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [], kvm_network_name = "qvexample-neta-loc-1" } }
  ]
}

# vm4: DHCP bridge only
module "vm4" {
  source     = "../../modules/quick-vm"
  name       = "vt4_dhcp_bridge_only"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-net-bridge", profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [], bridge = "br0", kvm_network_name = "qvexample-net-bridge" } }
  ]
}

# vm5: DHCP local only (same as vm3, different name)
module "vm5" {
  source     = "../../modules/quick-vm"
  name       = "vt5_dhcp_local_b"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-neta-loc-1", profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [], kvm_network_name = "qvexample-neta-loc-1" } }
  ]
}

# vm6: DHCP bridge only (same as vm4, different name)
module "vm6" {
  source     = "../../modules/quick-vm"
  name       = "vt6_dhcp_bridge_b"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-net-bridge", profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [], bridge = "br0", kvm_network_name = "qvexample-net-bridge" } }
  ]
}

# vm7: static IP using profile_name (reader auto-detects)
module "vm7" {
  source     = "../../modules/quick-vm"
  name       = "vt7_profile_name"
  user_data  = local.user_data
  vm_profile = local.vm_profile
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.20" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.20" }
  ]
}

output "vms" {
  value = {
    for name, mod in {
      vm1 = module.vm1
      vm2 = module.vm2
      vm3 = module.vm3
      vm4 = module.vm4
      vm5 = module.vm5
      vm6 = module.vm6
      vm7 = module.vm7
    } : name => {
      name     = mod.vm_name
      networks = mod.vm_networks
    }
  }
}