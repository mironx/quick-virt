variable "prefix" {
  description = "Prefix for VM names and volume names"
  type        = string
}

variable "kvm_networks" {
  description = "Map of KVM networks with enabled flag"
  type = map(object({
    enabled = optional(bool, true)
  }))
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

variable "user_data" {
  type = string
}

variable "user_data_after" {
  type    = string
  default = null
}

variable "vmdata_path" {
  description = "Absolute path to shared vmdata directory"
  type        = string
}

variable "test_clone_exception" {
  description = "Set to true to test clone validation error (disk_mode 'clone' is not supported)"
  type        = bool
  default     = false
}
