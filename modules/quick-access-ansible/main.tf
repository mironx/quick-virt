terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

//-------------------------------------------------------------------------------
// Flatten groups into a deduped set of VMs, compute primary_ip per VM (with
// fallback to networks[0] when primary_network is missing on the VM).
//-------------------------------------------------------------------------------

locals {
  _all_vms_raw = flatten(values(var.groups))

  _unique_names = distinct([for v in local._all_vms_raw : v.name])

  // Pick the first occurrence of each VM by name (dedup while preserving order).
  _unique_vms = [
    for name in local._unique_names :
    [for v in local._all_vms_raw : v if v.name == name][0]
  ]

  // For each VM: primary_ip = ip on primary_network if attached, else networks[0].ip
  vms = [
    for vm in local._unique_vms : merge(vm, {
      primary_ip = coalesce(
        var.primary_network == null ? null : try(
          [for n in vm.networks : n.ip if n.profile_name == var.primary_network][0],
          null,
        ),
        try(vm.networks[0].ip, null),
      )
    })
  ]

  // Group membership as list of VM names per group (deduped, order preserved).
  groups_by_vm_names = {
    for group_name, vms in var.groups :
    group_name => distinct([for v in vms : v.name])
  }

  output_path = coalesce(
    var.output_file,
    "${path.root}/.qv-access/${var.inventory_filename}"
  )
}

//-------------------------------------------------------------------------------
// Validate: every VM has a derivable primary_ip
//-------------------------------------------------------------------------------

resource "null_resource" "validate_primary_ip" {
  lifecycle {
    precondition {
      condition = alltrue([for vm in local.vms : vm.primary_ip != null])
      error_message = <<-EOT
        The following VMs have no derivable primary IP for the Ansible inventory:
          ${join(", ", [for vm in local.vms : vm.name if vm.primary_ip == null])}

        Each VM must have at least one network with a defined IP. Either:
          - Define a network on the VM, or
          - Set primary_network to a network that all listed VMs share.
      EOT
    }
  }
}

//-------------------------------------------------------------------------------
// Render inventory
//-------------------------------------------------------------------------------

resource "local_file" "inventory" {
  filename        = local.output_path
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.ini.tmpl", {
    vms    = local.vms
    groups = local.groups_by_vm_names
    ssh    = var.ssh
  })
}

resource "local_file" "gitignore" {
  filename        = "${dirname(local.output_path)}/.gitignore"
  file_permission = "0644"
  content         = "*\n"
}