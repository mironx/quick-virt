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
      condition     = local.selected_os.image != null && local.selected_os.image != ""
      error_message = "VM image must be defined and not empty. Set os_name or os_profile. [vm_name:${var.name}]"
    }

    precondition {
      condition = var.os_volume != null || var.os_profile != null || var.os_image_mode == "url" || fileexists(local.selected_os.image)
      error_message = <<-EOT
        Image file not found: ${local.selected_os.image}
        [vm_name:${var.name}, os_name:${coalesce(var.os_name, "ubuntu_22")}, image_mode:${var.os_image_mode}]

        Download it first:
          wget -O ${local.selected_os.image} ${local._builtin_os.image_url}

        Or switch to URL mode:
          image_mode = "url"
      EOT
    }
    precondition {
      condition = !(var.os_disk_mode == "clone" && var.os_volume != null)
      error_message = <<-EOT
        disk_mode "clone" with os_volume is not supported — libvirt creates volumes as root:root
        with 600 permissions, making file-based cloning from os_volume impossible.
        [vm_name:${var.name}]

        Options:
          - Use disk_mode = "backing_store" with os_volume (thin provisioning, shared base)
          - Use disk_mode = "clone" without os_volume (clone from original image source)
      EOT
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