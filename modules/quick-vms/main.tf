terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
  }
}

//-------------------------------------------------------------------------------
// Read network profiles for enabled networks without manual profile
//-------------------------------------------------------------------------------

locals {
  enabled_kvm_networks = {
    for name, net in var.kvm-networks : name => net if net.enabled
  }

  networks_needing_reader = {
    for name, net in local.enabled_kvm_networks : name => name
    if net.profile == null
  }
}

module "network_profile_reader" {
  for_each         = local.networks_needing_reader
  source           = "../quick-kvm-network-reader"
  kvm_network_name = each.value
}

locals {
  # Resolved profiles: manual profile > reader
  resolved_network_profiles = {
    for name, net in local.enabled_kvm_networks : name => (
      net.profile != null ? {
        kvm_network_name = try(net.profile.kvm_network_name, name)
        dhcp_mode        = try(net.profile.dhcp_mode, "static")
        gateway4         = net.profile.gateway4
        mask             = net.profile.mask
        nameservers      = net.profile.nameservers
        bridge           = try(net.profile.bridge, null)
        mode             = null
        error            = ""
      } : module.network_profile_reader[name].profile
    )
  }
}

//-------------------------------------------------------------------------------
// User data
//-------------------------------------------------------------------------------

locals {
  machines = var.machines

  user_data_map = {
    for set_key, set_val in var.machines :
    set_key => (
      set_val.cloud_init_user_data_template != null
      ? set_val.cloud_init_user_data_template
      : (
      set_val.cloud_init_user_data_path != null
      ? templatefile("${path.root}/${set_val.cloud_init_user_data_path}", {
        user_name     = set_val.user.name,
        user_password = set_val.user.password
      })
      : file("ERROR: Both cloud_init_user_data_template and cloud_init_user_data_path are null for set '${set_key}'")
      )
    )
  }
}

//-------------------------------------------------------------------------------
// Outputs
//-------------------------------------------------------------------------------

output "kvm-network-profiles" {
  value       = local.resolved_network_profiles
  description = "Resolved network profiles"
}

//-------------------------------------------------------------------------------
// Validate: all networks referenced by nodes must exist in kvm-networks
//-------------------------------------------------------------------------------

locals {
  _all_referenced_networks = distinct(flatten([
    for set_key, set_val in var.machines : [
      for node in set_val.nodes : [
        for net in node.networks : net.profile_name
      ]
    ]
  ]))

  _missing_networks = [
    for net_name in local._all_referenced_networks : net_name
    if !contains(keys(var.kvm-networks), net_name)
  ]
}

resource "null_resource" "validate_kvm_networks" {
  lifecycle {
    precondition {
      condition     = length(local._missing_networks) == 0
      error_message = <<-EOT
        The following networks are used in node definitions but not declared in kvm-networks:
          ${join(", ", local._missing_networks)}

        Add them to kvm-networks, for example:
          kvm-networks = {
            ${join("\n    ", [for n in local._missing_networks : "\"${n}\" = { enabled = true }"])}
          }
      EOT
    }
  }
}

//-------------------------------------------------------------------------------
// VMs
//-------------------------------------------------------------------------------

module "vms" {
  for_each = merge([
    for set_key, set_val in var.machines :
    {
      for node in set_val.nodes :
      "${set_key}-${node.name}" => {
        set_key      = set_key
        set_name     = set_val.set_name
        vm_profile   = set_val.vm_profile
        main_storage = set_val.main_storage
        user_data    = local.user_data_map[set_key]
        os_volume    = set_val.os_volume
        os_name      = set_val.os_name
        os_profile   = set_val.os_profile
        os_image_mode   = set_val.os_image_mode
        os_disk_mode    = set_val.os_disk_mode
        memory_backing  = set_val.memory_backing
        shared_folders  = set_val.shared_folders
        node         = node
      }
    }
  ]...)

  source       = "../quick-vm"
  name         = "${each.value.set_name}-${each.value.node.name}"
  description  = each.value.node.description
  user_data    = each.value.user_data
  vm_profile   = each.value.vm_profile
  main_storage = each.value.main_storage
  os_volume    = each.value.os_volume
  os_name      = each.value.os_name
  os_profile   = each.value.os_profile
  os_image_mode   = each.value.os_image_mode
  os_disk_mode    = each.value.os_disk_mode
  memory_backing  = each.value.memory_backing
  shared_folders  = each.value.shared_folders

  networks = [
    for net in each.value.node.networks : {
      profile_name = net.profile_name
      profile      = try(local.resolved_network_profiles[net.profile_name], null)
      ip           = net.ip
      enabled      = contains(keys(local.enabled_kvm_networks), net.profile_name)
    }
  ]
}

//-------------------------------------------------------------------------------
// SSH config & hosts generators
//-------------------------------------------------------------------------------

module "quick-ssh-config-generator" {
  for_each = local.machines
  source   = "../quick-ssh-config"
  set_name = each.value.set_name
  user     = each.value.user.name
  nodes    = each.value.nodes
}

module "quick-hosts-generator" {
  for_each = local.machines
  source   = "../quick-hosts"
  set_name = each.value.set_name
  nodes    = each.value.nodes
}