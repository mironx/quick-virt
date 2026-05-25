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
  prefix = "qvms-ex4"

  # Demo-only password — accessible via `virsh console <vm>` when SSH or
  # cloud-init is still booting. DO NOT reuse outside local KVM dev.
  user_password = "demo123"

  kvm_networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = true }
  }

  ssh = {
    user       = "ubuntu"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  user_data_master = templatefile("${path.module}/templates/master-user-data.tmpl", {
    user_name     = local.ssh.user
    user_password = local.user_password
    ssh_pub_key   = local.ssh.public_key
  })

  user_data_worker = templatefile("${path.module}/templates/worker-user-data.tmpl", {
    user_name     = local.ssh.user
    user_password = local.user_password
    ssh_pub_key   = local.ssh.public_key
  })
}

module "vms" {
  source = "../../modules/quick-vms"

  kvm-networks = local.kvm_networks

  machines = {
    masters = {
      set_name = "${local.prefix}-master"
      os_name  = "ubuntu_22"
      vm_profile = {
        vcpu   = 1
        memory = 2048
      }
      main_storage = {
        size = 30
      }
      user_data = local.user_data_master
      nodes = [
        {
          name        = "v1"
          description = "master 1/3"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.3" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.17" }
          ]
        },
        {
          name        = "v2"
          description = "master 2/3"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.4" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.18" }
          ]
        },
        {
          name        = "v3"
          description = "master 3/3"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.5" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.19" }
          ]
        }
      ]
    }
    workers = {
      set_name = "${local.prefix}-worker"
      os_name  = "ubuntu_22"
      vm_profile = {
        vcpu   = 3
        memory = 4096
      }
      main_storage = {
        size = 40
      }
      user_data = local.user_data_worker
      nodes = [
        {
          name        = "v1"
          description = "worker 1/4"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.33" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.37" }
          ]
        },
        {
          name        = "v2"
          description = "worker 2/4"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.34" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.38" }
          ]
        },
        {
          name        = "v3"
          description = "worker 3/4"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.35" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.39" }
          ]
        },
        {
          name        = "v4"
          description = "worker 4/4"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.36" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.40" }
          ]
        }
      ]
    }
  }
}

output "all_vms_info" {
  description = "Info for all VMs created by set_vms"
  value       = module.vms.vms_info
}

output "kvm_network_profiles" {
  description = "Resolved network profiles"
  value       = module.vms.kvm-network-profiles
}