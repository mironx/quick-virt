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

  ssh = {
    user          = "ubuntu"
    identity_file = "~/.ssh/id_rsa"
  }

  user_data_master = templatefile("${path.module}/templates/master-user-data.tmpl", {
    user_name     = local.ssh.user
    user_password = "ubuntu123"
  })

  user_data_worker = templatefile("${path.module}/templates/worker-user-data.tmpl", {
    user_name     = local.ssh.user
    user_password = "ubuntu123"
  })
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
      user_data = local.user_data_master
      ssh       = local.ssh
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
      user_data = local.user_data_worker
      ssh       = local.ssh
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

//-------------------------------------------------------------------------------
// Ansible inventory — masters/workers from quick-vms + custom "super" group
// holding worker-v1 and worker-v2 (multi-group: they stay in workers too).
//-------------------------------------------------------------------------------

module "ansible_add_super" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.vms.vms_info_by_set
  group_name = "super"
  vms = [
    for vm in module.vms.vms_info_by_set["workers"] : vm
    if contains(["${local.prefix}-worker-v1", "${local.prefix}-worker-v2"], vm.name)
  ]
}

module "ansible" {
  source = "../../modules/quick-access-ansible"
  groups = module.ansible_add_super.groups
  ssh = {
    user          = local.ssh.user
    identity_file = local.ssh.identity_file
    password      = "ubuntu123"
  }
  primary_network = "qvexample-neta-loc-2"
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory"
  value       = module.ansible.inventory_path
}

output "ansible_groups" {
  description = "Group membership (debug view)"
  value       = module.ansible.groups
}