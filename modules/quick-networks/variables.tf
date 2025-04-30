variable "networks" {
  type = map(object({
    mode             = string
    domain           = optional(string)
    kvm_network_name = string
    mask             = string
    gateway4         = string
    nameservers      = list(string)
    dhcp_mode        = string
    bridge           = optional(string)
    autostart        = bool
  }))
  description = "Map of network profiles."
}
