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
    description = "User data for cloud-init (runs before shared folders mount)"
}

variable "user_data_after" {
    type        = string
    description = "Additional cloud-init user data that runs after shared folders mount"
    default     = null
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
    vcpu   = number
    memory = number
    cpu = optional(object({
       mode = optional(string)
    }))
  })
}

variable "memory_backing" {
  description = "Memory backing configuration for the VM"
  type = object({
    shared       = optional(bool, true)
    source       = optional(string)
    locked       = optional(bool, false)
    discard      = optional(bool, false)
    nosharepages = optional(bool, false)
  })
  default = {}
}

variable "os_volume" {
  description = "Shared base volume from quick-os-volume module. Takes priority over os_name/os_profile."
  type = object({
    path = string
    name = string
    pool = string
    os_name = string
    os_profile = object({
      image            = string
      network_template = string
      interface_naming = string
      interface_offset = number
      fs_type          = string
    })
  })
  default = null
}

variable "os_name" {
  description = "Built-in OS profile name: ubuntu_22, ubuntu_24, rocky_9, debian_12"
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
    interface_offset = optional(number, 3)
    fs_type          = optional(string, "virtiofs")
  })
  default = null
}

variable "os_image_mode" {
  description = "Image source for built-in os_name profiles: 'local' uses local path, 'url' downloads from URL"
  type        = string
  default     = "local"
  validation {
    condition     = contains(["local", "url"], var.os_image_mode)
    error_message = "os_image_mode must be 'local' or 'url'"
  }
}

variable "fs_type" {
  description = "Filesystem type for shared folders: 'virtiofs' or '9p'. Overrides os_profile.fs_type if set."
  type        = string
  default     = "virtiofs"
  validation {
    condition     = var.fs_type == null || contains(["virtiofs", "9p"], var.fs_type)
    error_message = "fs_type must be 'virtiofs' or '9p'"
  }
}

variable "os_disk_mode" {
  description = "Disk provisioning: 'backing_store' (thin, fast, shared base) or 'clone' (full copy, independent)"
  type        = string
  default     = "backing_store"
  validation {
    condition     = contains(["backing_store", "clone"], var.os_disk_mode)
    error_message = "os_disk_mode must be 'backing_store' or 'clone'"
  }
}

variable "kvm-networks" {
  description = "Map of KVM networks for global enable/disable and optional manual profiles. If set, overrides per-network 'enabled' field."
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
  default = {}
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

variable "shared_folders" {
  description = "List of host directories to mount in the VM via 9p/virtio"
  type = list(object({
    source    = string
    target    = string
    read_only = optional(bool, false)
  }))
  default = []
}