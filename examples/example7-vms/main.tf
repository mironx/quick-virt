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
  prefix = "qvms-ex7"

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
      nodes = [
        {
          name        = "v1"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.100" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.100" }
          ]
        },
        {
          name        = "v2"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.101" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.101" }
          ]
        },
        {
          name        = "v3"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.102" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.102" }
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
      nodes = [
        {
          name        = "v1"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.110" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.110" }
          ]
        },
        {
          name        = "v2"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.111" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.111" }
          ]
        },
        {
          name        = "v3"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.112" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.112" }
          ]
        },
        {
          name        = "v4"
          description = "black virtual machine"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.113" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.113" }
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
// Standalone VM (quick-vm) — same networks as the quick-vms cluster above.
//-------------------------------------------------------------------------------

module "vm_extra" {
  source    = "../../modules/quick-vm"
  name      = "${local.prefix}-extra"
  os_name   = "ubuntu_22"
  user_data = local.user_data_master
  vm_profile = {
    vcpu   = 1
    memory = 2048
  }
  kvm-networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = true }
  }
  networks = [
    { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.120" },
    { profile_name = "qvexample-net-bridge", ip = "172.20.0.120" },
  ]
}

//-------------------------------------------------------------------------------
// Ansible inventory — masters/workers from quick-vms + custom "super" group
// holding worker-v1 and worker-v2. The standalone vm_extra is added to ALL
// three groups by chaining add_vms_to_group.
//-------------------------------------------------------------------------------

module "ansible_add_extra_to_masters" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.vms.vms_info_by_set
  group_name = "masters"
  vms        = [module.vm_extra.vm_info]
}

module "ansible_add_extra_to_workers" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.ansible_add_extra_to_masters.groups
  group_name = "workers"
  vms        = [module.vm_extra.vm_info]
}

module "ansible_add_super" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.ansible_add_extra_to_workers.groups
  group_name = "super"
  vms = concat(
    [
      for vm in module.vms.vms_info_by_set["workers"] : vm
      if contains(["${local.prefix}-worker-v1", "${local.prefix}-worker-v2"], vm.name)
    ],
    [module.vm_extra.vm_info],
  )
}

module "ansible_add_nodes" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.ansible_add_super.groups
  group_name = "nodes"
  vms = concat(
    module.vms.vms_info_by_set["masters"],
    module.vms.vms_info_by_set["workers"],
  )
}

module "ansible" {
  source = "../../modules/quick-access-ansible"
  groups = module.ansible_add_nodes.groups
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
