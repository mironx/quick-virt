variable "vm_profile" {
  type = object({
    vcpu      = number
    memory    = number
    user_name = string
  })
  description = "VM profile configuration."
}

variable "local_network" {
  type = object({
    mask        = string
    gateway4    = string
    nameservers = list(string)
    dhcp_mode   = string
  })
  description = "Static local network profile."
}

variable "bridge_network" {
  type = object({
    mask        = string
    gateway4    = string
    nameservers = list(string)
    dhcp_mode   = string
    bridge      = string
  })
  description = "Static bridge network profile."
}


variable "user" {
  type = object({
    name     = string
    password = string
  })
  description = "User profile configuration."
}
