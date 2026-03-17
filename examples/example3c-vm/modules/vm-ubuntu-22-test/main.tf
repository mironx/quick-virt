# ==============================================================================
# Ubuntu 22.04 test VMs — three ways to configure OS image
# ==============================================================================

locals {
  # "local" — use pre-downloaded image from disk (fast, requires manual download first)
  # "url"   — download image from the internet (slow first time, but automatic)
  os_image_mode = "local"
}

# ==============================================================================
# A, B, C — shared base volume via quick-os-volume
# One base image downloaded once, multiple thin VMs on top of it
# ==============================================================================

module "base_ubuntu_22" {
  source      = "../../../../modules/quick-os-volume"
  volume_name = "${var.prefix}-ubuntu-22"
  os_name     = "ubuntu_22"
  os_image_mode  = local.os_image_mode
}

module "vm_A" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-A"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode    = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.50" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.50" }
  ]
}

module "vm_B" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-B"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode    = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.54" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.54" }
  ]
}

module "vm_C" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-C"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode    = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.55" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.55" }
  ]
}

# ==============================================================================
# D1, D2 — os_disk_mode "clone" is NOT supported by libvirt provider 0.9.x
# due to file permission limitations (root:root 600).
# Set test_clone_exception = true to see the validation error.
# ==============================================================================

module "vm_D1" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-D1"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode    = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.56" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.56" }
  ]
}

module "vm_D2" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-D2"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode    = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.58" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.58" }
  ]
}

# ==============================================================================
# E — standalone, using custom os_profile with URL (no local image needed)
# VM creates its own reference volume internally, downloads image from URL
# ==============================================================================

module "vm_E" {
  source = "../../../../modules/quick-vm"
  name   = "${var.prefix}-ubuntu22-E"
  os_profile = {
    image            = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
    network_template = "netplan"
    interface_naming = "enp0s"
  }
  os_disk_mode    = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.57" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.57" }
  ]
}

# ==============================================================================
# F1, F2 — shared folder mounted from host
# ==============================================================================

module "vm_F1" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-F1"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  shared_folders = [
    { source = var.vmdata_path, target = "vmdata" }
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.40" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.40" }
  ]
}

module "vm_F2" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-ubuntu22-F2"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  shared_folders = [
    { source = var.vmdata_path, target = "vmdata" }
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.41" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.41" }
  ]
}
