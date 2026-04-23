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

# ==============================================================================
# example3d-vm — one VM per OS, each mounting the same NFS share
#
# Pre-flight on the host:
#   task setup:install-nfs-server
#   task setup:configure-nfs-export DIR=/home/$USER/vm-shares CIDR=192.168.200.0/24
#
# After apply, each VM writes /mnt/vm-shares/<name>.txt — visible on the host.
# ==============================================================================

locals {
  prefix = "qvms-ex3d"

  kvm_networks = {
    "qvexample-neta-loc-1" = { enabled = true }
    "qvexample-net-bridge" = { enabled = false }  # set to true when br0 is available
  }

  vm_profile = { vcpu = 1, memory = 2048 }

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = "ubuntu"
    user_password = "ubuntu123"
  })

  nfs_host   = "192.168.200.1"           # gateway of qvexample-neta-loc-1 == host IP on that NAT
  nfs_source = "/home/devx/vm-shares"
  nfs_target = "vm-shares"                # → mounted at /mnt/vm-shares in every VM
  output_subdir = "example3d-vm"          # per-example subdirectory so outputs don't mix with other exampleshmmm
}

module "vm_ubuntu_22" {
  source       = "../../modules/quick-vm"
  name         = "${local.prefix}-ubuntu22"
  os_name      = "ubuntu_22"
  user_data    = local.user_data
  vm_profile   = local.vm_profile
  kvm-networks = local.kvm_networks
  nfs_mounts = [
    { host = local.nfs_host, source = local.nfs_source, target = local.nfs_target }
  ]
  run_after = [
    "mountpoint -q /mnt/${local.nfs_target} && mkdir -p /mnt/${local.nfs_target}/${local.output_subdir} && echo ready > /mnt/${local.nfs_target}/${local.output_subdir}/${local.prefix}-ubuntu22.txt",
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.70" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.70" }
  ]
}

module "vm_ubuntu_24" {
  source       = "../../modules/quick-vm"
  name         = "${local.prefix}-ubuntu24"
  os_name      = "ubuntu_24"
  user_data    = local.user_data
  vm_profile   = local.vm_profile
  kvm-networks = local.kvm_networks
  nfs_mounts = [
    { host = local.nfs_host, source = local.nfs_source, target = local.nfs_target }
  ]
  run_after = [
    "mountpoint -q /mnt/${local.nfs_target} && mkdir -p /mnt/${local.nfs_target}/${local.output_subdir} && echo ready > /mnt/${local.nfs_target}/${local.output_subdir}/${local.prefix}-ubuntu24.txt",
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.71" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.71" }
  ]
}

module "vm_rocky_9" {
  source       = "../../modules/quick-vm"
  name         = "${local.prefix}-rocky9"
  os_name      = "rocky_9"
  user_data    = local.user_data
  vm_profile   = local.vm_profile
  kvm-networks = local.kvm_networks
  nfs_mounts = [
    { host = local.nfs_host, source = local.nfs_source, target = local.nfs_target }
  ]
  run_after = [
    "mountpoint -q /mnt/${local.nfs_target} && mkdir -p /mnt/${local.nfs_target}/${local.output_subdir} && echo ready > /mnt/${local.nfs_target}/${local.output_subdir}/${local.prefix}-rocky9.txt",
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.72" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.72" }
  ]
}

module "vm_debian_12" {
  source       = "../../modules/quick-vm"
  name         = "${local.prefix}-debian12"
  os_name      = "debian_12"
  user_data    = local.user_data
  vm_profile   = local.vm_profile
  kvm-networks = local.kvm_networks
  nfs_mounts = [
    { host = local.nfs_host, source = local.nfs_source, target = local.nfs_target }
  ]
  run_after = [
    "mountpoint -q /mnt/${local.nfs_target} && mkdir -p /mnt/${local.nfs_target}/${local.output_subdir} && echo ready > /mnt/${local.nfs_target}/${local.output_subdir}/${local.prefix}-debian12.txt",
  ]
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.73" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.73" }
  ]
}

output "vms" {
  value = {
    ubuntu_22 = { name = module.vm_ubuntu_22.vm_name, networks = module.vm_ubuntu_22.vm_networks }
    ubuntu_24 = { name = module.vm_ubuntu_24.vm_name, networks = module.vm_ubuntu_24.vm_networks }
    rocky_9   = { name = module.vm_rocky_9.vm_name,   networks = module.vm_rocky_9.vm_networks }
    debian_12 = { name = module.vm_debian_12.vm_name, networks = module.vm_debian_12.vm_networks }
  }
}