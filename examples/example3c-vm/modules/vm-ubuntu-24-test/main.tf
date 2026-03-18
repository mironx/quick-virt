# ==============================================================================
# Ubuntu 24.04 test VMs — three ways to configure OS image
# ==============================================================================

locals {
  os_image_mode = "local"
}

# ==============================================================================
# A, B, C — shared base volume via quick-os-volume
# ==============================================================================

module "base_ubuntu_24" {
  source        = "../../../../modules/quick-os-volume"
  volume_name   = "${var.prefix}-ubuntu-24"
  os_name       = "ubuntu_24"
  os_image_mode = local.os_image_mode
}

module "vm_A" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-A"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.60" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.60" }
  ]
}

module "vm_B" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-B"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.64" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.64" }
  ]
}

module "vm_C" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-C"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.65" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.65" }
  ]
}

# ==============================================================================
# D1, D2 — os_disk_mode "clone" with os_volume is NOT supported
# Set test_clone_exception = true to see the validation error.
# ==============================================================================

module "vm_D1" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-D1"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.66" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.66" }
  ]
}

module "vm_D2" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-D2"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.68" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.68" }
  ]
}

# ==============================================================================
# E — standalone, using custom os_profile
# ==============================================================================

module "vm_E" {
  source = "../../../../modules/quick-vm"
  name   = "${var.prefix}-ubuntu24-E"
  os_profile = {
    image            = "/var/lib/libvirt/images/ubuntu-2404.qcow2.base"
    network_template = "netplan"
    interface_naming = "enp0s"
  }
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.67" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.67" }
  ]
}

# ==============================================================================
# F1, F2 — shared folder mounted from host
# ==============================================================================

module "vm_F1" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-F1"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  shared_folders = [
    { source = var.vmdata_path, target = "vmdata" }
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.42" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.42" }
  ]
}

module "vm_F2" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu24-F2"
  os_volume    = module.base_ubuntu_24.volume
  os_disk_mode    = "backing_store"
  fs_type         = "9p"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  shared_folders = [
    { source = var.vmdata_path, target = "vmdata" }
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.43" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.43" }
  ]
}