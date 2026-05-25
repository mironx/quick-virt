variable "groups" {
  description = <<-EOT
    Map of group name to list of vm_info objects.

    Shape matches quick-access-ansible.groups / quick-access-hosts.groups for
    cross-module consistency. quick-access-ssh ignores the group structure
    (deduplicates by VM name and renders a single ssh-config file). Group keys
    are kept for API parity.

    Example:
      groups = module.vms.vms_info_by_set
  EOT
  type    = any
  default = {}
}

variable "ssh" {
  description = "SSH connection settings used in every Host block (User, IdentityFile)."
  type = object({
    user          = string
    identity_file = optional(string, "~/.ssh/id_rsa")
  })
}

variable "primary_network" {
  description = <<-EOT
    Profile name of the network whose IP is the HostName for the bare-name
    Host block (required). VMs without this network attached fall back to
    networks[0].ip. Secondary networks become 'Host <vm>.<suffix>' entries
    (controlled by emit_secondary_networks and network_aliases).
  EOT
  type        = string

  validation {
    condition     = length(var.primary_network) > 0
    error_message = "primary_network must be a non-empty string."
  }
}

variable "emit_secondary_networks" {
  description = "When true (default), each non-primary network on a VM also gets a 'Host <vm>.<suffix>' block."
  type        = bool
  default     = true
}

variable "network_aliases" {
  description = <<-EOT
    Map of profile_name => short alias used as the suffix after '<vm>.' for non-primary networks.
    When a profile_name is not in this map, the full profile_name is used as suffix.
  EOT
  type        = map(string)
  default     = {}
}

variable "relaxed_host_keys" {
  description = <<-EOT
    When true (default), each Host block gets:
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
    Convenient for dev VMs that get recreated; set to false for stricter security.
  EOT
  type        = bool
  default     = true
}

variable "ssh_config_filename" {
  description = "Filename for the generated ssh-config. Placed under <path.root>/.qv-access/."
  type        = string
  default     = "ssh-config"

  validation {
    condition     = length(var.ssh_config_filename) > 0
    error_message = "ssh_config_filename must be a non-empty string."
  }
}
