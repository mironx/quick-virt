terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

module "local_network_profile_reader" {
  count             = var.local-kvm-network-name != null ? 1 : 0
  source      = "../quick-kvm-network-reader"
  kvm_network_name = var.local-kvm-network-name
}

module "bridge_network_profile_reader" {
  count             = var.bridge-kvm-network-name != null ? 1 : 0
  source      = "../quick-kvm-network-reader"
  kvm_network_name = var.bridge-kvm-network-name
}

locals {
  machines = var.machines

  local_network_profile_static = (
    var.local-kvm-network-name != null && length(module.local_network_profile_reader) > 0
    ? module.local_network_profile_reader[0].profile
    : null
  )

  bridge_network_profile_static = (
    var.bridge-kvm-network-name != null && length(module.bridge_network_profile_reader) > 0
    ? module.bridge_network_profile_reader[0].profile
    : null
  )

  user_data_map = {
    for set_key, set_val in var.machines :
    set_key => templatefile("${path.root}/${set_val.cloud_unit_user_data}", {
      user_name     = set_val.user.name,
      user_password = set_val.user.password
    })
  }
}


output "local-network-profile" {
  value = local.local_network_profile_static
  description = "local network profile"
}

output "bridge-network-profile" {
  value = local.bridge_network_profile_static
  description = "bridge network profile"
}

module "vms" {
  for_each = merge([
    for set_key, set_val in var.machines :
    {
      for node in set_val.nodes :
      "${set_key}-${node.name}" => {
      set_key    = set_key
      set_name   = set_val.set_name
      vm_profile = set_val.vm_profile
      user_data  = local.user_data_map[set_key]
      node       = node
    }
    }
  ]...)

  source      = "../quick-vm"
  name        = "${each.value.set_name}-${each.value.node.name}"
  description = each.value.node.description
  user_data   = each.value.user_data
  vm_profile  = each.value.vm_profile

  local_network = (

    each.value.node.local_ip != null && local.local_network_profile_static != null ? {
    is_enabled = true
    ip      = each.value.node.local_ip
    profile = local.local_network_profile_static
  } : {
    is_enabled = false
    ip        = null
    profile    = null
  }
  )

  bridge_network = (
    each.value.node.bridge_ip != null && local.bridge_network_profile_static != null ? {
    is_enabled = true
    ip      = each.value.node.bridge_ip
    profile = local.bridge_network_profile_static
  } : {
    is_enabled = false
    ip        = null
    profile    = null
  }
  )
}

module "quick-ssh-config-generator" {
    for_each    = local.machines
    source = "../quick-ssh-config"
    set_name = each.value.set_name
    nodes = each.value.nodes
}


module "quick-hosts-generator" {
    for_each    = local.machines
    source = "../quick-hosts"
    set_name = each.value.set_name
    nodes = each.value.nodes
}


