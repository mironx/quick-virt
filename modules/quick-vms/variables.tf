variable "machines" {
  type = map(object({
    set_name = string
    vm_profile = object({
      vcpu   = number
      memory = number
      cpu    = optional(object({
        mode = optional(string)
      }))
    })
    user = object({
      name     = string
      password = string
    })
    cloud_unit_user_data = string
    nodes = list(object({
      name        = string
      local_ip    = optional(string)
      bridge_ip   = optional(string)
      description = optional(string)
    }))
  }))
  description = "Map of machine configurations including VM and user profile."
}

variable "local-kvm-network-name" {
  type = string
  description = "Name of the KVM network."
  default = null
}

variable "bridge-kvm-network-name" {
  type = string
  description = "Name of the KVM network."
  default = null
}