resource "null_resource" "validate" {
  triggers = {
    always_run = timestamp()
  }
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
      condition     = local.current_vm_profile.user_name != null && local.current_vm_profile.user_name != ""
      error_message = "VM user_name must be defined and not empty [vm_name:${var.name}]"
    }

    precondition {
      condition     = local.current_vm_profile.image_source != null && local.current_vm_profile.image_source != ""
      error_message = "VM image_source must be defined and not empty [vm_name:${var.name}]"
    }

    precondition {
      condition     = local.current_vm_profile.network_desc_order != null
      error_message = "VM network_desc_order must be defined (even if false) [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}

# Validate local_network
#--------------------------------------------------------------------------------------------------------
resource "null_resource" "validate_local_network" {
  lifecycle {
    precondition {
      condition     = !(local.current_local_network.is_enabled && local.current_local_network.profile == null)
      error_message = "local_network.profile must be set when is_enabled is true"
    }

    precondition {
      condition     = local.current_local_network.profile.dhcp_mode != "static" || (
        local.current_local_network.ip != null && local.current_local_network.ip != "" &&
        local.current_local_network.profile.mask != null && local.current_local_network.profile.mask != "" &&
        local.current_local_network.profile.gateway4 != null && local.current_local_network.profile.gateway4 != "" &&
        local.current_local_network.profile.nameservers != null &&
        length(local.current_local_network.profile.nameservers) > 0
      )
      error_message = "local_network is in static mode but required fields (ip, mask, gateway4, nameservers) are missing [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}


# Validate bridge_network
#--------------------------------------------------------------------------------------------------------
resource "null_resource" "validate_bridge_network" {
  lifecycle {
    precondition {
      condition     = !(local.current_bridge_network.is_enabled && local.current_bridge_network.profile == null)
      error_message = "bridge_network.profile must be set when is_enabled is true"
    }

    precondition {
      condition     = local.current_bridge_network.profile.dhcp_mode != "static" || (
        local.current_bridge_network.ip != null && local.current_bridge_network.ip != "" &&
        local.current_bridge_network.profile.mask != null && local.current_bridge_network.profile.mask != "" &&
        local.current_bridge_network.profile.gateway4 != null && local.current_bridge_network.profile.gateway4 != "" &&
        local.current_bridge_network.profile.bridge != null && local.current_bridge_network.profile.bridge != "" &&
        local.current_bridge_network.profile.nameservers != null &&
        length(local.current_bridge_network.profile.nameservers) > 0
      )
      error_message = "bridge_network is in static mode but required fields (ip, mask, gateway4, nameservers) are missing [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}
