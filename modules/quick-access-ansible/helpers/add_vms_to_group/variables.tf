variable "groups" {
  description = <<-EOT
    Existing groups map (same shape as quick-access-ansible.groups).
    Pass an empty map {} when building groups from scratch.
  EOT
  type        = any
  default     = {}
}

variable "group_name" {
  description = "Name of the group to add VMs into. Created if it does not exist."
  type        = string

  validation {
    condition     = length(var.group_name) > 0
    error_message = "group_name must be a non-empty string."
  }
}

variable "vms" {
  description = "List of vm_info objects to add to the group. Duplicates against existing members are tolerated; the main module dedupes on render."
  type        = any
  default     = []
}