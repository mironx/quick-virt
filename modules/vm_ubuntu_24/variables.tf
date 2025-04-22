variable "vm" {
  type = object({
    name         = string
    image_source = string
    vcpu         = number
    memory       = number
    user_name    = string
    network_desc_order = bool
  })

  default = {
    name         = "vm_test_1"
    image_source = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
    vcpu         = 2
    memory       = 2048
    user_name    = "devx"
    network_desc_order = false
  }

  validation {
    condition     = var.vm.name != null && var.vm.name != ""
    error_message = "Variable vm.name must be defined."
  }

  validation {
    condition     = var.vm.image_source != null && var.vm.image_source != ""
    error_message = "Variable vm.image_source must be defined."
  }
}


// local_network_name = "local-network"
// local_network_addresses = ["192.168.100.0/24"]
variable "local_network_configuration" {
  type = object({
    is_enabled = bool
    ip = string
    mask = string
    gateway4 = string
    nameservers = list(string)
    dhcp_mode = string # enum: "dhcp", "ips_static_other_dhcp", "static"
  })
  # default = {
  #   is_enabled = true
  #   ip = ""
  #   mask = ""
  #   # ip = "192.168.100.15"
  #   # mask = "24"
  #   gateway4 = ""
  #   nameservers = []
  #   # gateway4 = "192.168.100.1"
  #   # nameservers = ["1.1.1.1", "8.8.8.8"]
  #   dhcp_mode = "ips_static_other_dhcp"
  # }
  # validation {
  #   condition = contains(["dhcp", "ips_static_other_dhcp", "static"], var.local_network_configuration.dhcp_mode)
  #   error_message = "Allowed values for dhcp_mode: dhcp, ips_static_other_dhcp, static"
  # }

  # # Validation for dhcp mode - ip, mask, gateway4, nameservers should be empty
  # validation {
  #   condition = var.local_network_configuration.dhcp_mode != "dhcp" || (
  #    (var.local_network_configuration.ip == null || var.local_network_configuration.ip == "") &&
  #    (var.local_network_configuration.mask == null || var.local_network_configuration.mask == "") &&
  #    (var.local_network_configuration.gateway4 == null || var.local_network_configuration.gateway4 == "") &&
  #    (var.local_network_configuration.nameservers == null || length(var.local_network_configuration.nameservers) == 0)
  #   )
  #   error_message = "When dhcp_mode is set to 'dhcp', the fields ip, mask, gateway4, and nameservers must be empty"
  # }
  #
  # # Validation for ips_static_other_dhcp mode - ip and mask must be set, gateway4 and nameservers should be empty
  # validation {
  #   condition = var.local_network_configuration.dhcp_mode != "ips_static_other_dhcp" || (
  #    (var.local_network_configuration.ip != null && var.local_network_configuration.ip != "")  &&
  #    (var.local_network_configuration.mask != null && var.local_network_configuration.mask != "" ) &&
  #    (var.local_network_configuration.gateway4 == null || var.local_network_configuration.gateway4 == "" )&&
  #    (var.local_network_configuration.nameservers == null || length(var.local_network_configuration.nameservers) == 0)
  #   )
  #   error_message = "When dhcp_mode is set to 'ips_static_other_dhcp', the fields ip and mask must be set, while gateway4 and nameservers must be empty"
  # }
  #
  # # Validation for static mode - all fields must be set
  # validation {
  #   condition = var.local_network_configuration.dhcp_mode != "static" || (
  #     (var.local_network_configuration.ip != null && var.local_network_configuration.ip != "" ) &&
  #     (var.local_network_configuration.mask != null && var.local_network_configuration.mask != "") &&
  #     (var.local_network_configuration.gateway4 != null && var.local_network_configuration.gateway4 != "") &&
  #     (var.local_network_configuration.nameservers != null && length(var.local_network_configuration.nameservers) > 0)
  #   )
  #   error_message = "When dhcp_mode is set to 'static', the fields ip, mask, gateway4, and nameservers must be set"
  # }
}

// Bridge network configuration
variable "bridge_network_configuration" {
  type = object({
    is_enabled = bool
    ip = string
    mask = string
    gateway4 = string
    nameservers = list(string)
    dhcp_mode = string # enum: "dhcp", "ips_static_other_dhcp", "static"
  })
  # default = {
  #   is_enabled = true
  #   ip = ""
  #   mask = ""
  #   # ip = "172.16.0.15"
  #   # mask = "12"
  #   gateway4 = ""
  #   nameservers = []
  #   # gateway4 = "172.16.0.1"
  #   # nameservers = ["172.16.0.1"]
  #   dhcp_mode = "ips_static_other_dhcp"
  # }
  # validation {
  #   condition = contains(["dhcp", "ips_static_other_dhcp", "static"], var.bridge_network_configuration.dhcp_mode)
  #   error_message = "Allowed values for dhcp_mode: dhcp, ips_static_other_dhcp, static"
  # }

 # # Validation for dhcp mode - ip, mask, gateway4, nameservers should be empty
 #  validation {
 #    condition = var.bridge_network_configuration.dhcp_mode != "dhcp" || (
 #     (var.bridge_network_configuration.ip == null || var.bridge_network_configuration.ip == "") &&
 #     (var.bridge_network_configuration.mask == null || var.bridge_network_configuration.mask == "") &&
 #     (var.bridge_network_configuration.gateway4 == null || var.bridge_network_configuration.gateway4 == "") &&
 #     (var.bridge_network_configuration.nameservers == null || length(var.bridge_network_configuration.nameservers) == 0)
 #    )
 #    error_message = "When dhcp_mode is set to 'dhcp', the fields ip, mask, gateway4, and nameservers must be empty"
 #  }
 #
 #  # Validation for ips_static_other_dhcp mode - ip and mask must be set, gateway4 and nameservers should be empty
 #  validation {
 #    condition = var.bridge_network_configuration.dhcp_mode != "ips_static_other_dhcp" || (
 #     (var.bridge_network_configuration.ip != null && var.bridge_network_configuration.ip != "")  &&
 #     (var.bridge_network_configuration.mask != null && var.bridge_network_configuration.mask != "" ) #&&
 #     # (var.bridge_network_configuration.gateway4 == null || var.bridge_network_configuration.gateway4 == "" )&&
 #     # (var.bridge_network_configuration.nameservers == null || length(var.bridge_network_configuration.nameservers) == 0)
 #    )
 #    error_message = "When dhcp_mode is set to 'ips_static_other_dhcp', the fields ip and mask must be set, while gateway4 and nameservers must be empty"
 #  }
 #
 #  # Validation for static mode - all fields must be set
 #  validation {
 #    condition = var.bridge_network_configuration.dhcp_mode != "static" || (
 #      (var.bridge_network_configuration.ip != null && var.bridge_network_configuration.ip != "" ) &&
 #      (var.bridge_network_configuration.mask != null && var.bridge_network_configuration.mask != "") &&
 #      (var.bridge_network_configuration.gateway4 != null && var.bridge_network_configuration.gateway4 != "") &&
 #      (var.bridge_network_configuration.nameservers != null && length(var.bridge_network_configuration.nameservers) > 0)
 #    )
 #    error_message = "When dhcp_mode is set to 'static', the fields ip, mask, gateway4, and nameservers must be set"
 #  }
}