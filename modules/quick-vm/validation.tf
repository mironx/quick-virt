resource "null_resource" "validate" {
}

resource "null_resource" "validate_vm" {
  lifecycle {
    precondition {
      condition     = local.current_vm_profile.vcpu != null && local.current_vm_profile.vcpu > 0
      error_message = "VM vCPU must be defined and greater than 0 [vm_name:${var.name}]"
    }

    precondition {
      condition     = local.current_vm_profile.memory != null && local.current_vm_profile.memory > 0
      error_message = "VM memory must be defined and greater than 0 [vm_name:${var.name}]"
    }

    precondition {
      condition     = local.selected_os.image != null && local.selected_os.image != ""
      error_message = "VM image must be defined and not empty. Set os_name or os_profile. [vm_name:${var.name}]"
    }

    precondition {
      condition = var.os_volume != null || var.os_profile != null || var.os_image_mode == "url" || fileexists(local.selected_os.image)
      error_message = <<-EOT
        Image file not found: ${local.selected_os.image}
        [vm_name:${var.name}, os_name:${coalesce(var.os_name, "ubuntu_22")}, image_mode:${var.os_image_mode}]

        Download it first:
          wget -O ${local.selected_os.image} ${local._builtin_os.image_url}

        Or switch to URL mode:
          image_mode = "url"
      EOT
    }
    precondition {
      condition = !(var.os_disk_mode == "clone" && var.os_volume != null)
      error_message = <<-EOT
        disk_mode "clone" with os_volume is not supported — libvirt creates volumes as root:root
        with 600 permissions, making file-based cloning from os_volume impossible.
        [vm_name:${var.name}]

        Options:
          - Use disk_mode = "backing_store" with os_volume (thin provisioning, shared base)
          - Use disk_mode = "clone" without os_volume (clone from original image source)
      EOT
    }
  }
  depends_on = [null_resource.validate]
}

resource "null_resource" "validate_networks" {
  for_each = { for idx, n in local.resolved_networks : tostring(idx) => n }

  lifecycle {
    precondition {
      condition     = each.value.profile != null
      error_message = "Network ${each.key} (profile_name: ${try(each.value.profile_name, "none")}) has no profile. Provide profile_name or profile. [vm_name:${var.name}]"
    }

    precondition {
      condition     = try(each.value.profile.error, "") == ""
      error_message = "Network ${each.key} (${try(each.value.profile_name, "unknown")}) has an error: ${try(each.value.profile.error, "")} [vm_name:${var.name}]"
    }

    precondition {
      condition = try(each.value.profile.dhcp_mode, "static") == "dhcp" || (
        each.value.ip != null && each.value.ip != "" &&
        try(each.value.profile.mask, "") != "" &&
        try(each.value.profile.gateway4, "") != "" &&
        try(each.value.profile.nameservers, []) != []
      )
      error_message = "Network ${each.key} is static but missing required fields (ip, mask, gateway4, nameservers) [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}

resource "null_resource" "validate_shared_folders" {
  for_each = { for idx, f in var.shared_folders : tostring(idx) => f }

  lifecycle {
    precondition {
      condition     = each.value.source != null && each.value.source != ""
      error_message = "Shared folder source path must not be empty [vm_name:${var.name}, target:${each.value.target}]"
    }

    precondition {
      condition     = each.value.target != null && each.value.target != ""
      error_message = "Shared folder target (mount tag) must not be empty [vm_name:${var.name}]"
    }

    precondition {
      condition = fileexists("${each.value.source}/.gitkeep")
      error_message = <<-EOT
        Shared folder directory not found: ${each.value.source}
        [vm_name:${var.name}, target:${each.value.target}]

        Create it:
          mkdir -p ${basename(each.value.source)} && touch ${basename(each.value.source)}/.gitkeep
      EOT
    }

    precondition {
      condition = !(local.fs_type == "9p" && contains(["rocky_9"], coalesce(var.os_name, try(var.os_volume.os_name, ""))))
      error_message = <<-EOT
        fs_type "9p" is not supported on Rocky Linux 9 — kernel does not include 9p module.
        [vm_name:${var.name}]

        Use fs_type = "virtiofs" instead (default).
      EOT
    }
  }
  depends_on = [null_resource.validate]
}

resource "null_resource" "validate_resource_limits" {
  lifecycle {
    precondition {
      condition     = try(var.vm_profile.cpu.limit.percent, null) == null || (var.vm_profile.cpu.limit.percent > 0 && var.vm_profile.cpu.limit.percent <= 100)
      error_message = "vm_profile.cpu.limit.percent must be in (0, 100] [vm_name:${var.name}]"
    }

    precondition {
      condition     = try(var.vm_profile.cpu.limit.period_us, null) == null || (var.vm_profile.cpu.limit.period_us >= 1000 && var.vm_profile.cpu.limit.period_us <= 1000000)
      error_message = "vm_profile.cpu.limit.period_us must be in [1000, 1000000] microseconds [vm_name:${var.name}]"
    }

    precondition {
      condition     = try(var.vm_profile.cpu.limit.quota_us, null) == null || var.vm_profile.cpu.limit.quota_us > 0
      error_message = "vm_profile.cpu.limit.quota_us must be > 0 [vm_name:${var.name}]"
    }

    precondition {
      condition = alltrue([
        for dev, t in coalesce(try(var.vm_profile.io, null), {}) :
        alltrue([
          try(t.read_bytes_sec,   0) >= 0,
          try(t.write_bytes_sec,  0) >= 0,
          try(t.read_iops_sec,    0) >= 0,
          try(t.write_iops_sec,   0) >= 0,
        ])
      ])
      error_message = "vm_profile.io.<dev>.* values must be >= 0 (0 = unlimited) [vm_name:${var.name}]"
    }

    precondition {
      condition = alltrue(flatten([
        for dev, t in coalesce(try(var.vm_profile.io, null), {}) : [
          for u in compact([
            try(t.bytes_unit, null),
            try(t.read_bytes_sec_unit, null),
            try(t.write_bytes_sec_unit, null),
            try(t.read_bytes_sec_max_unit, null),
            try(t.write_bytes_sec_max_unit, null),
          ]) : contains(["B", "KB", "MB", "GB"], u)
        ]
      ]))
      error_message = "vm_profile.io.<dev>.*_unit must be one of: B, KB, MB, GB [vm_name:${var.name}]"
    }

    precondition {
      condition = alltrue(flatten([
        for iface, cfg in coalesce(try(var.vm_profile.network, null), {}) : [
          for u in compact([
            try(cfg.rate_unit, null),
            try(cfg.inbound.average_unit,  null), try(cfg.inbound.peak_unit,  null), try(cfg.inbound.burst_unit,  null), try(cfg.inbound.floor_unit,  null),
            try(cfg.outbound.average_unit, null), try(cfg.outbound.peak_unit, null), try(cfg.outbound.burst_unit, null), try(cfg.outbound.floor_unit, null),
          ]) : contains(["KB", "MB", "GB"], u)
        ]
      ]))
      error_message = "vm_profile.network.<iface>.*_unit must be one of: KB, MB, GB [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}

resource "null_resource" "validate_nfs_mounts" {
  for_each = { for idx, m in var.nfs_mounts : tostring(idx) => m }

  lifecycle {
    precondition {
      condition     = each.value.host != null && each.value.host != ""
      error_message = "NFS mount host must not be empty [vm_name:${var.name}, target:${each.value.target}]"
    }

    precondition {
      condition     = each.value.source != null && each.value.source != ""
      error_message = "NFS mount source path must not be empty [vm_name:${var.name}, target:${each.value.target}]"
    }

    precondition {
      condition     = each.value.target != null && each.value.target != ""
      error_message = "NFS mount target (mount point name) must not be empty [vm_name:${var.name}]"
    }
  }
  depends_on = [null_resource.validate]
}