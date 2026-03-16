variable "name" {
    type = string
    description = "Name of the VM"
    validation {
        condition     = length(var.name) > 0
        error_message = "VM name must be defined and not empty"
    }
}

variable "running" {
  type = bool
  description = "Use false to turn off the instance. If not specified, true is assumed and the instance, if stopped, will be started at next apply."
  default = true
}

variable "autostart" {
  type = bool
  description = "Set to true to start the domain on host boot up. If not specified false is assumed."
  default = false
}

variable "description" {
  type = string
  description = "The description for domain. Changing this forces a new resource to be created. This data is not used by libvirt in any way, it can contain any information the user wants."
  default = null
}

variable "storage_pool" {
  type = string
  description = "The storage pool to use for the VM disk"
  default = "default"
}

variable "user_data" {
    type = string
    description = "User data for cloud-init"
}

variable "main_storage" {
  description = "Configuration options for the VM's main disk"
  type = object({
    size = optional(number, 20)
  })
  default = null
}

variable "vm_profile" {
  type = object({
    image_source = optional(string)
    vcpu         = number
    memory       = number
    cpu = optional(object({
       mode = optional(string)
    }))
  })
}

variable "networks" {
  description = "List of networks to attach to the VM. Order determines interface order (index 0 = enp0s3, index 1 = enp0s4, etc.)"
  type = list(object({
    profile_name = optional(string)
    profile = optional(object({
      kvm_network_name = optional(string)
      dhcp_mode        = optional(string, "static")
      gateway4         = string
      mask             = string
      nameservers      = list(string)
      bridge           = optional(string)
      error            = optional(string, "")
    }))
    ip      = optional(string)
    enabled = optional(bool, true)
  }))
  default = []
}