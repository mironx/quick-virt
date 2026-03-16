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
}

module "vms" {
  source = "../../modules/quick-vms"

  kvm-networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = true }
  }

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
      user = {
        name     = "ubuntu"
        password = "ubuntu123"
      }
      cloud_init_user_data_path = "./templates/master-user-data.tmpl"
      nodes = [
        {
          name        = "v1"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.3" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.17" }
          ]
        },
        {
          name        = "v2"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.4" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.18" }
          ]
        },
        {
          name        = "v3"
          description = "black virtual machine"
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
        memory = 4048
      }
      main_storage = {
        size = 40
      }
      user = {
        name     = "ubuntu"
        password = "ubuntu123"
      }
      cloud_init_user_data_path = "./templates/worker-user-data.tmpl"
      nodes = [
        {
          name        = "v1"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.33" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.37" }
          ]
        },
        {
          name        = "v2"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.34" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.38" }
          ]
        },
        {
          name        = "v3"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.35" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.39" }
          ]
        },
        {
          name        = "v4"
          description = "black virtual machine"
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