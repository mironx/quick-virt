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
  prefix = "qvms-ex3c"

  kvm_networks = {
    "qvexample-neta-loc-1" = { enabled = true }
    "qvexample-net-bridge" = { enabled = false }  # set to true when br0 is available
  }

  vm_profile = { vcpu = 1, memory = 2048 }

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = "ubuntu"
    user_password = "ubuntu123"
  })

}

module "ubuntu_22_test" {
  source       = "./modules/vm-ubuntu-22-test"
  prefix       = "${local.prefix}-u22"
  kvm_networks = local.kvm_networks
  vm_profile   = local.vm_profile
  user_data   = local.user_data
  vmdata_path = "${abspath(path.module)}/vmdata"
}

module "ubuntu_24_test" {
  source       = "./modules/vm-ubuntu-24-test"
  prefix       = "${local.prefix}-u24"
  kvm_networks = local.kvm_networks
  vm_profile   = local.vm_profile
  user_data   = local.user_data
  vmdata_path = "${abspath(path.module)}/vmdata"
}

module "rocky_9_test" {
  source       = "./modules/vm-rocky-9-test"
  prefix       = "${local.prefix}-r9"
  kvm_networks = local.kvm_networks
  vm_profile   = local.vm_profile
  user_data   = local.user_data
  vmdata_path = "${abspath(path.module)}/vmdata"
}

module "debian_12_test" {
  source       = "./modules/vm-debian-12-test"
  prefix       = "${local.prefix}-d12"
  kvm_networks = local.kvm_networks
  vm_profile   = local.vm_profile
  user_data   = local.user_data
  vmdata_path = "${abspath(path.module)}/vmdata"
}

output "ubuntu_22" {
  value = module.ubuntu_22_test.vms
}

output "ubuntu_24" {
  value = module.ubuntu_24_test.vms
}

output "rocky_9" {
  value = module.rocky_9_test.vms
}

output "debian_12" {
  value = module.debian_12_test.vms
}