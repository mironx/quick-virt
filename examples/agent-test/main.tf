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

# ----------------------------------------------------------------------------
# Dedicated example: validate the qemu guest-agent channel.
# quick-vm adds the agent virtio channel when user_data contains
# "qemu-guest-agent". The channel MUST be type='unix' (host socket) for
# `virsh --mode agent` / qemu-agent-command to work — type='pty' = broken.
#
# Static IP on neta-loc-3 (NAT + internet) so cloud-init can apt-install the
# agent quickly. Minimal user-data (NO package_upgrade) for fast boot.
# ----------------------------------------------------------------------------
locals {
  ssh_pub_key = chomp(file("~/.ssh/id_rsa.pub"))

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    ssh_pub_key = local.ssh_pub_key
  })
}

module "vm" {
  source     = "../../modules/quick-vm"
  name       = "qv-agent-test"
  os_name    = "ubuntu_22"
  user_data  = local.user_data
  vm_profile = { vcpu = 2, memory = 2048 }
  networks = [
    { profile_name = "neta-loc-3", ip = "192.168.102.55" }
  ]

  # Test new swap+memlock plumbing
  memory_backing = { locked = true }
  swap_level     = "disabled"
}

output "vm_name" { value = module.vm.vm_name }
output "ip" { value = "192.168.102.55" }
output "agent_test" {
  value = "virsh qemu-agent-command qv-agent-test '{\"execute\":\"guest-ping\"}'"
}
