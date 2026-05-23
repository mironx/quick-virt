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
    Profile name of the network to use as ansible_host for each VM.
    If a VM does not have this network attached, falls back to networks[0].ip.
    When null (default), every VM uses networks[0].ip.
  EOT
  type        = string
  default     = null
}

variable "output_file" {
  description = "Destination path for the generated inventory file."
  type        = string
  default     = null
}

variable "inventory_filename" {
  description = "Filename used when output_file is null. Placed under <path.root>/.qv-access/."
  type        = string
  default     = "inventory.ini"
}