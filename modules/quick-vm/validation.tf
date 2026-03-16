resource "null_resource" "validate" {
}

resource "null_resource" "validate_vm" {
  lifecycle {
    precondition {
      condition     = local.current_vm_profile.vcpu != null && local.current_vm_profile.vcpu > 0
      error_message = "VM vCPU must be defined and greater than 0 [vm_name:${var.name}]"
    }

    precondition {
      condition     = local.current_vm_profile.memory != null && local.current_vm_profile.memory > 0
      error_message = "VM memory must be defined and greater than 0 [vm_name:${var.name}]"
    }

    precondition {
      condition     = local.current_vm_profile.image_source != null && local.current_vm_profile.image_source != ""
      error_message = "VM image_source must be defined and not empty [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}

resource "null_resource" "validate_networks" {
  for_each = { for idx, n in local.resolved_networks : tostring(idx) => n }

  lifecycle {
    precondition {
      condition     = each.value.profile != null
      error_message = "Network ${each.key} (profile_name: ${try(each.value.profile_name, "none")}) has no profile. Provide profile_name or profile. [vm_name:${var.name}]"
    }

    precondition {
      condition     = try(each.value.profile.error, "") == ""
      error_message = "Network ${each.key} (${try(each.value.profile_name, "unknown")}) has an error: ${try(each.value.profile.error, "")} [vm_name:${var.name}]"
    }

    precondition {
      condition = try(each.value.profile.dhcp_mode, "static") == "dhcp" || (
        each.value.ip != null && each.value.ip != "" &&
        try(each.value.profile.mask, "") != "" &&
        try(each.value.profile.gateway4, "") != "" &&
        try(each.value.profile.nameservers, []) != []
      )
      error_message = "Network ${each.key} is static but missing required fields (ip, mask, gateway4, nameservers) [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}