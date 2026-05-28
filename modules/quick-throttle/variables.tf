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

  validation {
    condition = alltrue([
      for k, v in var.cpu_configs :
      try(v.limit.percent, null) == null ||
      (v.limit.percent >= 1 && v.limit.percent <= 100)
    ])
    error_message = "cpu_configs.<name>.limit.percent must be in [1, 100]."
  }

  validation {
    condition = alltrue([
      for k, v in var.cpu_configs :
      try(v.limit.period_us, null) == null || v.limit.period_us > 0
    ])
    error_message = "cpu_configs.<name>.limit.period_us must be > 0 (microseconds)."
  }

  validation {
    condition = alltrue([
      for k, v in var.cpu_configs :
      try(v.limit.shares, null) == null ||
      (v.limit.shares >= 2 && v.limit.shares <= 262144)
    ])
    error_message = "cpu_configs.<name>.limit.shares must be in [2, 262144] (libvirt cgroup range). Note: shares is SOFT priority under contention, NOT a hard cap."
  }
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

  validation {
    condition = alltrue(flatten([
      for cfg_name, devs in var.disk_configs : [
        for dev, t in devs :
        try(t.bytes_unit, null) == null || contains(["B", "KB", "MB", "GB"], t.bytes_unit)
      ]
    ]))
    error_message = "disk_configs.<name>.<dev>.bytes_unit must be one of: B, KB, MB, GB."
  }
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

  validation {
    condition = alltrue(flatten([
      for cfg_name, ifaces in var.network_configs : [
        for idx, n in ifaces :
        try(n.rate_unit, null) == null || contains(["KB", "MB", "GB"], n.rate_unit)
      ]
    ]))
    error_message = "network_configs.<name>.<idx>.rate_unit must be one of: KB, MB, GB."
  }

  validation {
    condition = alltrue(flatten([
      for cfg_name, ifaces in var.network_configs : [
        for idx, n in ifaces :
        try(n.outbound.floor, null) == null ||
        try(n.outbound.average, null) == null ||
        n.outbound.floor <= n.outbound.average
      ]
    ]))
    error_message = "network_configs.<name>.<idx>.outbound.floor must be <= outbound.average (otherwise floor is unreachable). Note: floor works only on NAT networks with QoS — silently ignored on bridge networks."
  }
}
