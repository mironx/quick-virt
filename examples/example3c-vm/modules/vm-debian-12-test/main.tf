# ==============================================================================
# Debian 12 test VMs — three ways to configure OS image
# ==============================================================================

locals {
  os_image_mode = "local"
}

# ==============================================================================
# A, B, C — shared base volume via quick-os-volume
# ==============================================================================

module "base_debian_12" {
  source        = "../../../../modules/quick-os-volume"
  volume_name   = "${var.prefix}-debian-12"
  os_name       = "debian_12"
  os_image_mode = local.os_image_mode
}

module "vm_A" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-A"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.80" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.80" }
  ]
}

module "vm_B" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-B"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.84" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.84" }
  ]
}

module "vm_C" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-C"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.85" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.85" }
  ]
}

# ==============================================================================
# D1, D2 — os_disk_mode "clone" with os_volume is NOT supported
# Set test_clone_exception = true to see the validation error.
# ==============================================================================

module "vm_D1" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-D1"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.86" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.86" }
  ]
}

module "vm_D2" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-D2"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.88" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.88" }
  ]
}

# ==============================================================================
# E — standalone, using custom os_profile
# ==============================================================================

module "vm_E" {
  source = "../../../../modules/quick-vm"
  name   = "${var.prefix}-debian12-E"
  os_profile = {
    image            = "/var/lib/libvirt/images/debian-12.qcow2.base"
    network_template = "netplan"
    interface_naming = "enp0s"
  }
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.87" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.87" }
  ]
}

# ==============================================================================
# F1, F2 — shared folder mounted from host
# ==============================================================================

module "vm_F1" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-F1"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  run_after = [
    "mountpoint -q /mnt/vmdata 2>/dev/null && echo ready > /mnt/vmdata/${var.prefix}-F1.txt",
  ]
  shared_folders = [
    { source = var.vmdata_path, target = "vmdata" }
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.46" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.46" }
  ]
}

module "vm_F2" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-F2"
  os_volume    = module.base_debian_12.volume
  os_disk_mode    = "backing_store"
  fs_type         = "9p"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  run_after = [
    "mountpoint -q /mnt/vmdata 2>/dev/null && echo ready > /mnt/vmdata/${var.prefix}-F2.txt",
  ]
  shared_folders = [
    { source = var.vmdata_path, target = "vmdata" }
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.47" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.47" }
  ]
}

module "vm_F3" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-debian12-F3"
  os_volume    = module.base_debian_12.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  nfs_mounts = [
    { host = "192.168.200.1", source = "/home/devx/vm-shares", target = "vm-shares" }
  ]
  run_after = [
    "mountpoint -q /mnt/vm-shares 2>/dev/null && echo ready > /mnt/vm-shares/${var.prefix}-F3.txt",
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.63" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.63" }
  ]
}