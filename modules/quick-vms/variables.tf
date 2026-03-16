variable "kvm-networks" {
  description = "Map of KVM networks. Key is network name. Use enabled=false to disable a network globally."
  type = map(object({
    enabled = optional(bool, true)
    profile = optional(object({
      kvm_network_name = optional(string)
      dhcp_mode        = optional(string, "static")
      gateway4         = string
      mask             = string
      nameservers      = list(string)
      bridge           = optional(string)
    }))
  }))
}

variable "machines" {
  type = map(object({
    set_name = string
    vm_profile = object({
      vcpu   = number
      memory = number
      cpu = optional(object({
        mode = optional(string)
      }))
    })
    main_storage = optional(object({
      size = optional(number, 20)
    }))
    user = object({
      name     = string
      password = string
    })
    cloud_init_user_data_path     = optional(string)
    cloud_init_user_data_template = optional(string)

    nodes = list(object({
      name        = string
      description = optional(string)
      networks = optional(list(object({
        profile_name = string
        ip           = optional(string)
      })), [])
    }))
  }))
  description = "Map of machine configurations including VM and user profile."
}