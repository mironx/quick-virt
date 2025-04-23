resource "null_resource" "validate" {
  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "validate_vm" {
  lifecycle {
    precondition {
      condition     = local.current_vm_profile.vcpu != null && local.current_vm_profile.vcpu > 0
      error_message = "VM vCPU must be defined and greater than 0"
    }

    precondition {
      condition     = local.current_vm_profile.memory != null && local.current_vm_profile.memory > 0
      error_message = "VM memory must be defined and greater than 0"
    }

    precondition {
      condition     = local.current_vm_profile.user_name != null && local.current_vm_profile.user_name != ""
      error_message = "VM user_name must be defined and not empty"
    }

    precondition {
      condition     = local.current_vm_profile.image_source != null && local.current_vm_profile.image_source != ""
      error_message = "VM image_source must be defined and not empty"
    }

    precondition {
      condition     = local.current_vm_profile.network_desc_order != null
      error_message = "VM network_desc_order must be defined (even if false)"
    }
  }
  depends_on = [null_resource.validate]
}
