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

variable "user_data_after" {
    type        = string
    description = "Additional cloud-init user data that runs after shared folders mount"
    default     = null
}

variable "run_before" {
    type        = list(string)
    description = "List of commands to run before user_data (right after hostname setup)"
    default     = []
}

variable "run_after" {
    type        = list(string)
    description = "List of commands to run after shared folders mount, before user_data_after"
    default     = []
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
      limit = optional(object({
        percent   = optional(number)
        period_us = optional(number)
        quota_us  = optional(number)
        shares    = optional(number)
      }))
    }))

    # Per-disk I/O throttle. Key = <target dev> (e.g. "vda").
    #
    # Byte fields support unit multipliers. Precedence (highest wins):
    #   1. Per-field: <field>_unit   (e.g. write_bytes_sec_unit = "KB")
    #   2. Disk-level: bytes_unit    (default unit for all *_bytes_sec*)
    #   3. Default: "B"              (raw bytes)
    # Valid units: "B" (=1), "KB" (=1024), "MB" (=1048576), "GB" (=1073741824).
    # *_max_length is always seconds — no unit.
    io = optional(map(object({
      bytes_unit                      = optional(string)

      read_bytes_sec                  = optional(number)
      read_bytes_sec_unit             = optional(string)
      write_bytes_sec                 = optional(number)
      write_bytes_sec_unit            = optional(string)
      read_iops_sec                   = optional(number)
      write_iops_sec                  = optional(number)

      read_bytes_sec_max              = optional(number)
      read_bytes_sec_max_unit         = optional(string)
      read_bytes_sec_max_length       = optional(number)
      write_bytes_sec_max             = optional(number)
      write_bytes_sec_max_unit        = optional(string)
      write_bytes_sec_max_length      = optional(number)
      read_iops_sec_max               = optional(number)
      read_iops_sec_max_length        = optional(number)
      write_iops_sec_max              = optional(number)
      write_iops_sec_max_length       = optional(number)
    })))

    # Per-interface network bandwidth throttle. Key = interface index as string
    # ("0" for networks[0], "1" for networks[1], ...).
    #
    # Libvirt native unit is KiB/s for rates and KiB for burst. User values are
    # multiplied by rate_unit ("KB"=1, "MB"=1024, "GB"=1048576) so you can write
    # rate_unit="MB" + average=100 to mean "100 MiB/s".
    network = optional(map(object({
      rate_unit = optional(string)
      inbound = optional(object({
        average      = optional(number)
        average_unit = optional(string)
        peak         = optional(number)
        peak_unit    = optional(string)
        burst        = optional(number)
        burst_unit   = optional(string)
        floor        = optional(number)
        floor_unit   = optional(string)
      }))
      outbound = optional(object({
        average      = optional(number)
        average_unit = optional(string)
        peak         = optional(number)
        peak_unit    = optional(string)
        burst        = optional(number)
        burst_unit   = optional(string)
        floor        = optional(number)
        floor_unit   = optional(string)
      }))
    })))

    # enable_config: inject <cputune> / <iotune> / <bandwidth> into the domain XML (persistent).
    # enable_live  : write sidecar .ini + .sh into path.root/.qv-limits/ (for live-apply via virsh).
    enable_config = optional(bool, true)
    enable_live   = optional(bool, false)
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

variable "nfs_mounts" {
  description = "List of NFS shares to mount in the VM. Each entry becomes /mnt/<target>."
  type = list(object({
    host    = string
    source  = string
    target  = string
    options = optional(string, "defaults")
  }))
  default = []
}