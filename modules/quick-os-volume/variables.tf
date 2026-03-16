variable "volume_name" {
  description = "Name for the base volume in libvirt pool"
  type        = string
}

variable "os_name" {
  description = "Built-in OS profile: ubuntu_22, ubuntu_24, rocky_9, debian_12"
  type        = string
  default     = null
  validation {
    condition     = var.os_name == null || contains(["ubuntu_22", "ubuntu_24", "rocky_9", "debian_12"], var.os_name)
    error_message = "os_name must be one of: ubuntu_22, ubuntu_24, rocky_9, debian_12"
  }
}

variable "os_profile" {
  description = "Custom OS profile. Takes priority over os_name."
  type = object({
    image            = string
    network_template = optional(string, "netplan")
    interface_naming = optional(string, "enp0s")
  })
  default = null
  validation {
    condition     = var.os_profile == null || contains(["netplan", "networkmanager"], try(var.os_profile.network_template, "netplan"))
    error_message = "network_template must be 'netplan' or 'networkmanager'"
  }
  validation {
    condition     = var.os_profile == null || contains(["enp0s", "eth", "ens"], try(var.os_profile.interface_naming, "enp0s"))
    error_message = "interface_naming must be one of: enp0s, eth, ens"
  }
}

variable "os_image_mode" {
  description = "'local' or 'url'"
  type        = string
  default     = "local"
  validation {
    condition     = contains(["local", "url"], var.os_image_mode)
    error_message = "os_image_mode must be 'local' or 'url'"
  }
}

variable "storage_pool" {
  type    = string
  default = "default"
}