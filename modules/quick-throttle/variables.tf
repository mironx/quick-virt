# ============================================================================
# Inputs for quick-throttle — three independent named collections,
# one per throttle axis. Each entry generates ONE .ini file in
# .qv-limits/ named <axis>-<entry_key>.ini.
# ============================================================================

variable "output_dir" {
  type        = string
  description = "Directory under which .qv-limits/ is created. Typically path.root in the caller."
}

variable "prefix" {
  type        = string
  description = "Mandatory namespace prefix for ALL generated files (e.g. 'k3s2-lap', 'cassandra'). Final naming: <prefix>-<axis>-<name>.ini. Lets multiple unrelated chaos scenarios coexist in the same .qv-limits/ without colliding."
  validation {
    condition     = length(var.prefix) > 0 && can(regex("^[A-Za-z0-9][A-Za-z0-9_-]*$", var.prefix))
    error_message = "prefix must be non-empty and contain only alphanumerics, underscore, hyphen (starting with alphanumeric)."
  }
}

# ----------------------------------------------------------------------------
# CPU configs. Each entry → cpu-<name>.ini with [cpu] section.
# Shape mirrors quick-vm.vm_profile.cpu (single throttle spec per entry).
# ----------------------------------------------------------------------------
variable "cpu_configs" {
  type = map(object({
    mode = optional(string)
    limit = optional(object({
      percent   = optional(number)
      period_us = optional(number)
      quota_us  = optional(number)
      shares    = optional(number)
    }))
  }))
  description = "Named CPU throttle configs. Key = config name (becomes filename suffix)."
  default     = {}
}

# ----------------------------------------------------------------------------
# Disk configs. Each entry → disk-<name>.ini with one or more [io.<dev>] sections.
# An entry is map(target_dev → throttle), supporting multi-disk VMs.
# Shape mirrors quick-vm.vm_profile.io.
# ----------------------------------------------------------------------------
variable "disk_configs" {
  type = map(map(object({
    bytes_unit                 = optional(string)
    read_bytes_sec             = optional(number)
    read_bytes_sec_unit        = optional(string)
    write_bytes_sec            = optional(number)
    write_bytes_sec_unit       = optional(string)
    read_iops_sec              = optional(number)
    write_iops_sec             = optional(number)
    read_bytes_sec_max         = optional(number)
    read_bytes_sec_max_unit    = optional(string)
    read_bytes_sec_max_length  = optional(number)
    write_bytes_sec_max        = optional(number)
    write_bytes_sec_max_unit   = optional(string)
    write_bytes_sec_max_length = optional(number)
    read_iops_sec_max          = optional(number)
    read_iops_sec_max_length   = optional(number)
    write_iops_sec_max         = optional(number)
    write_iops_sec_max_length  = optional(number)
  })))
  description = "Named disk-throttle configs. Outer key = config name (filename suffix). Inner key = target dev (vda, vdb, ...)."
  default     = {}
}

# ----------------------------------------------------------------------------
# Network configs. Each entry → network-<name>.ini with one or more
# [net.<iface>] sections. Inner key = interface index as string ("0", "1").
# Shape mirrors quick-vm.vm_profile.network.
# ----------------------------------------------------------------------------
variable "network_configs" {
  type = map(map(object({
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
  description = "Named network-throttle configs. Outer key = config name (filename suffix). Inner key = interface index ('0', '1', ...)."
  default     = {}
}
