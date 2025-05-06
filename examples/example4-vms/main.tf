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

# resource "null_resource" "debug" {
#   triggers = {
#     always_run = timestamp()
#   }
#   lifecycle {
#     precondition {
#       condition = local.machines == null
#       error_message = "machines=${jsonencode(var.machines)}"
#     }
#   }
# }

locals {
  machines = var.machines
  local-kvm-network-name = var.local-kvm-network-name
  bridge-kvm-network-name = var.bridge-kvm-network-name
}

module "vms" {
  source      = "../../modules/quick-vms"
  machines    = local.machines
  local-kvm-network-name = local.local-kvm-network-name
  bridge-kvm-network-name = local.bridge-kvm-network-name
}

output "all_vms_info" {
  description = "Info for all VMs created by set_vms"
  value       = module.vms.vms_info
}

output "local_network_profile" {
  description = "local network profile"
  value       = module.vms.local-network-profile
}

output "bridge_network_profile" {
  description = "bridge network profile"
  value       = module.vms.bridge-network-profile
}