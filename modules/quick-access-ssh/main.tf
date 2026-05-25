terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

//-------------------------------------------------------------------------------
// Flatten groups, dedupe VMs by name, then for each VM build a list of
// {ip, host} entries: bare-name for primary network + suffixed for the rest.
// Identical algorithm to quick-access-hosts; only the rendered file format
// differs (SSH config vs /etc/hosts).
//-------------------------------------------------------------------------------

locals {
  _all_vms_raw  = flatten(values(var.groups))
  _unique_names = distinct([for v in local._all_vms_raw : v.name])
  _unique_vms = [
    for name in local._unique_names :
    [for v in local._all_vms_raw : v if v.name == name][0]
  ]

  _vms_with_primary = [
    for vm in local._unique_vms : merge(vm, {
      primary_net_profile = (
        contains([for n in vm.networks : n.profile_name], var.primary_network)
        ? var.primary_network
        : try(vm.networks[0].profile_name, null)
      )
    })
  ]

  vms = [
    for vm in local._vms_with_primary : {
      name = vm.name
      primary_ip = try(
        [for n in vm.networks : n.ip if n.profile_name == vm.primary_net_profile][0],
        null
      )
      entries = concat(
        [
          {
            ip   = try([for n in vm.networks : n.ip if n.profile_name == vm.primary_net_profile][0], "")
            host = vm.name
          }
        ],
        var.emit_secondary_networks ? [
          for n in vm.networks : {
            ip   = n.ip
            host = "${vm.name}.${lookup(var.network_aliases, n.profile_name, n.profile_name)}"
          } if n.profile_name != vm.primary_net_profile
        ] : []
      )
    }
  ]

  output_path = "${path.root}/.qv-access/${var.ssh_config_filename}"
}

//-------------------------------------------------------------------------------
// Validate: every VM has at least one network with an IP (primary derivable).
//-------------------------------------------------------------------------------

resource "null_resource" "validate_primary_ip" {
  lifecycle {
    precondition {
      condition = alltrue([for vm in local.vms : vm.primary_ip != null])
      error_message = <<-EOT
        The following VMs have no derivable primary IP for the ssh-config file:
          ${join(", ", [for vm in local.vms : vm.name if vm.primary_ip == null])}

        Each VM must declare at least one network with an IP.
      EOT
    }
  }
}

//-------------------------------------------------------------------------------
// Render ssh-config file
//-------------------------------------------------------------------------------

resource "local_file" "ssh_config" {
  filename        = local.output_path
  file_permission = "0644"
  content = templatefile("${path.module}/templates/ssh-config.tmpl", {
    vms               = local.vms
    ssh               = var.ssh
    relaxed_host_keys = var.relaxed_host_keys
  })
}

resource "local_file" "gitignore" {
  filename        = "${dirname(local.output_path)}/.gitignore"
  file_permission = "0644"
  content         = "*\n"
}
