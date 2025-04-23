variable "name" {
    type = string
    description = "Name of the VM"
    validation {
        condition     = length(var.name) > 0
        error_message = "VM name must be defined and not empty"
    }
}

variable "vm_profile" {
  type = object({
    image_source = optional(string)
    vcpu         = number
    memory       = number
    user_name    = string
    network_desc_order = optional(bool)
  })
}

variable "local_network" {
  type = object({
    ip = optional(string)
    is_enabled = optional(bool)
    profile = optional(object({
      dhcp_mode = optional(string)
      mask      = optional(string)
      gateway4  = optional(string)
      nameservers = optional(list(string))
    }))
  })
  default = {
    ip = null
    is_enabled = false
  }
}


variable "bridge_network" {
   type = object({
    ip = optional(string)
    is_enabled = optional(bool)
    profile = optional(object({
      dhcp_mode = optional(string)
      mask      = optional(string)
      gateway4  = optional(string)
      nameservers = optional(list(string))
      bridge = string
    }))
  })
  default = {
    ip = null
    is_enabled = false
  }
}