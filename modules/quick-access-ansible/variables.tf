variable "groups" {
  description = <<-EOT
    Map of Ansible group name to list of vm_info objects.

    A VM can appear in multiple groups simultaneously (multi-group membership).
    The vm_info shape comes from quick-vm.vm_info or quick-vms.vms_info_by_set.

    Example:
      groups = merge(
        module.vms.vms_info_by_set,
        { databases = [module.db.vm_info] },
      )
  EOT
  type    = any
  default = {}
}

variable "ssh" {
  description = "Global SSH/Ansible connection settings (emitted under [all:vars])"
  type = object({
    user            = string
    identity_file   = optional(string, "~/.ssh/id_rsa")
    password        = optional(string)
    become_password = optional(string)
  })
}

variable "primary_network" {
  description = <<-EOT
    Profile name of the network used as ansible_host for each VM (required).
    If a VM does not have this network attached, falls back to networks[0].ip.
  EOT
  type        = string

  validation {
    condition     = length(var.primary_network) > 0
    error_message = "primary_network must be a non-empty string."
  }
}

variable "inventory_filename" {
  description = "Filename for the generated inventory. Placed under <path.root>/.qv-access/."
  type        = string
  default     = "inventory.ini"

  validation {
    condition     = length(var.inventory_filename) > 0
    error_message = "inventory_filename must be a non-empty string."
  }
}