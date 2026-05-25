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

//-------------------------------------------------------------------------------
// vms1 — first quick-vms instance: masters + workers, 2 nodes per group
//-------------------------------------------------------------------------------

module "vms1" {
  source = "../../modules/quick-vms"

  kvm-networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = true }
  }

  machines = {
    masters = {
      set_name = "vms1-${local.prefix}-master"
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
        }
      ]
    }
    workers = {
      set_name = "vms1-${local.prefix}-worker"
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
        }
      ]
    }
  }
}

//-------------------------------------------------------------------------------
// vms2 — second quick-vms instance: databases + cache, 2 nodes per group
//-------------------------------------------------------------------------------

module "vms2" {
  source = "../../modules/quick-vms"

  kvm-networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = true }
  }

  machines = {
    masters = {
      set_name = "vms2-${local.prefix}-master"
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
        }
      ]
    }
    workers = {
      set_name = "vms2-${local.prefix}-worker"
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
        }
      ]
    }
  }
}

output "all_vms_info" {
  description = "Info for all VMs from both quick-vms instances"
  value = {
    vms1 = module.vms1.vms_info_by_set
    vms2 = module.vms2.vms_info_by_set
  }
}

output "kvm_network_profiles" {
  description = "Resolved network profiles"
  value       = module.vms1.kvm-network-profiles
}

//-------------------------------------------------------------------------------
// Standalone VM (quick-vm) — same networks as the quick-vms clusters above.
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
    { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.150" },
    { profile_name = "qvexample-net-bridge", ip = "172.20.0.150" },
  ]
}

//-------------------------------------------------------------------------------
// Merged base groups — concat lists on overlapping keys (built-in merge() would
// override one list with the other; merge_groups helper concatenates them).
//-------------------------------------------------------------------------------

module "merge_groups" {
  source = "../../modules/quick-access-ansible/helpers/merge_groups"
  group_maps = [
    module.vms1.vms_info_by_set,
    module.vms2.vms_info_by_set,
  ]
}

locals {
  base_groups = module.merge_groups.groups
}

//-------------------------------------------------------------------------------
// Ansible inventory — base groups + custom "super" group (worker-v1, worker-v2)
// + "nodes" group (all cluster VMs from both vms1 and vms2).
// The standalone vm_extra is added to masters, workers, and super.
//-------------------------------------------------------------------------------

module "ansible_add_extra_to_masters" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = local.base_groups
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
      for vm in module.vms1.vms_info_by_set["workers"] : vm
      if contains(["${local.prefix}-worker-v1", "${local.prefix}-worker-v2"], vm.name)
    ],
    [module.vm_extra.vm_info],
  )
}

module "ansible_add_nodes" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.ansible_add_super.groups
  group_name = "nodes"
  vms        = flatten(values(local.base_groups))
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

//-------------------------------------------------------------------------------
// /etc/hosts-style file — all VMs from vms1 + vms2 + vm_extra; group keys
// ignored, deduped by name.
//-------------------------------------------------------------------------------

module "hosts" {
  source = "../../modules/quick-access-hosts"
  groups = merge(
    local.base_groups,
    { extra = [module.vm_extra.vm_info] },
  )
  primary_network = "qvexample-neta-loc-2"
  network_aliases = {
    "qvexample-net-bridge" = "br"
  }
}

output "hosts_path" {
  description = "Path to the generated hosts file"
  value       = module.hosts.hosts_path
}
