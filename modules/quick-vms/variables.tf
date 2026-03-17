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

    os_volume = optional(object({
      path    = string
      name    = string
      pool    = string
      os_name = string
      os_profile = object({
        image            = string
        network_template = string
        interface_naming = string
        interface_offset = number
      })
    }))
    os_name    = optional(string)
    os_profile = optional(object({
      image            = string
      network_template = optional(string, "netplan")
      interface_naming = optional(string, "enp0s")
      interface_offset = optional(number, 3)
    }))
    os_image_mode = optional(string, "local")
    os_disk_mode  = optional(string, "backing_store")

    shared_folders = optional(list(object({
      source    = string
      target    = string
      read_only = optional(bool, false)
    })), [])

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