# ==============================================================================
# Rocky Linux 9 test VMs — three ways to configure OS image
# ==============================================================================

locals {
  os_image_mode = "local"
}

# ==============================================================================
# A, B, C — shared base volume via quick-os-volume
# ==============================================================================

module "base_rocky_9" {
  source        = "../../../../modules/quick-os-volume"
  volume_name   = "${var.prefix}-rocky-9"
  os_name       = "rocky_9"
  os_image_mode = local.os_image_mode
}

module "vm_A" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-A"
  os_volume    = module.base_rocky_9.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.70" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.70" }
  ]
}

module "vm_B" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-B"
  os_volume    = module.base_rocky_9.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.74" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.74" }
  ]
}

module "vm_C" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-C"
  os_volume    = module.base_rocky_9.volume
  os_disk_mode = "backing_store"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.75" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.75" }
  ]
}

# ==============================================================================
# D1, D2 — os_disk_mode "clone" with os_volume is NOT supported
# Set test_clone_exception = true to see the validation error.
# ==============================================================================

module "vm_D1" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-D1"
  os_volume    = module.base_rocky_9.volume
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.76" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.76" }
  ]
}

module "vm_D2" {
  count        = var.test_clone_exception ? 1 : 0
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-D2"
  os_volume    = module.base_rocky_9.volume
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.78" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.78" }
  ]
}

# ==============================================================================
# E — standalone, using custom os_profile
# ==============================================================================

module "vm_E" {
  source = "../../../../modules/quick-vm"
  name   = "${var.prefix}-rocky9-E"
  os_profile = {
    image            = "/var/lib/libvirt/images/rocky-9.qcow2.base"
    network_template = "networkmanager"
    interface_naming = "eth"
  }
  os_disk_mode = "clone"
  user_data    = var.user_data
  vm_profile   = var.vm_profile
  kvm-networks = var.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.77" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.77" }
  ]
}

# ==============================================================================
# F1, F2 — shared folder mounted from host
# ==============================================================================

module "vm_F1" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-F1"
  os_volume    = module.base_rocky_9.volume
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
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.44" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.44" }
  ]
}

module "vm_F2" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-F2"
  os_volume    = module.base_rocky_9.volume
  os_disk_mode    = "backing_store"
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
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.45" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.45" }
  ]
}

module "vm_F3" {
  source       = "../../../../modules/quick-vm"
  name         = "${var.prefix}-rocky9-F3"
  os_volume    = module.base_rocky_9.volume
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
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.62" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.62" }
  ]
}