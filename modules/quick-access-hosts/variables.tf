variable "groups" {
  description = <<-EOT
    Map of group name to list of vm_info objects.

    Shape matches quick-access-ansible.groups for cross-module consistency.
    quick-access-hosts ignores the group structure (it deduplicates by VM name
    and renders one /etc/hosts-style file). Group keys are kept for API parity.

    Example:
      groups = module.vms.vms_info_by_set
  EOT
  type    = any
  default = {}
}

variable "primary_network" {
  description = <<-EOT
    Profile name of the network whose IP gets the bare VM name in the hosts file
    (required). VMs without this network attached fall back to networks[0].ip
    for their bare-name line. Secondary networks are emitted with a suffix
    (controlled by emit_secondary_networks and network_aliases).
  EOT
  type        = string

  validation {
    condition     = length(var.primary_network) > 0
    error_message = "primary_network must be a non-empty string."
  }
}

variable "emit_secondary_networks" {
  description = "When true (default), each non-primary network on a VM also gets a hosts line as '<vm>.<suffix>'."
  type        = bool
  default     = true
}

variable "network_aliases" {
  description = <<-EOT
    Map of profile_name => short alias used as the suffix after '<vm>.' for non-primary networks.
    When a profile_name is not in this map, the full profile_name is used as suffix.

    Example:
      network_aliases = {
        "qvexample-net-bridge" = "br"
        "qvexample-neta-loc-2" = "loc"
      }
  EOT
  type        = map(string)
  default     = {}
}

variable "hosts_filename" {
  description = "Filename for the generated hosts file. Placed under <path.root>/.qv-access/."
  type        = string
  default     = "hosts"

  validation {
    condition     = length(var.hosts_filename) > 0
    error_message = "hosts_filename must be a non-empty string."
  }
}
