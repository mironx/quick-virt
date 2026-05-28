terraform {
  required_version = ">= 1.3"
}

# ============================================================================
# Per-axis normalization + file generation.
# Each input collection (cpu_configs / disk_configs / network_configs) is
# rendered independently — no cross-axis dependencies, no preset bundling.
# Output filenames: <axis>-<key>.ini (e.g. cpu-cap25.ini, disk-slow1.ini).
# ============================================================================

locals {
  _byte_units = { B = 1, KB = 1024, MB = 1048576, GB = 1073741824 }
  _net_units  = { KB = 1, MB = 1024, GB = 1048576 }

  # --------------------------------------------------------------------------
  # CPU — pass values through as-is (apply.sh downstream resolves percent
  # → quota_us using vcpu from `virsh dominfo` when needed).
  # --------------------------------------------------------------------------
  cpu_normalized = {
    for name, cfg in var.cpu_configs : name => cfg.limit == null ? null : {
      percent   = cfg.limit.percent
      period_us = cfg.limit.period_us
      quota_us  = cfg.limit.quota_us
      shares    = cfg.limit.shares
    }
  }

  # --------------------------------------------------------------------------
  # Disk — convert bytes_unit (B/KB/MB/GB) to raw bytes.
  # Inner map(dev → throttle) preserved; per-dev sections in the .ini.
  # --------------------------------------------------------------------------
  disk_normalized = {
    for name, devs in var.disk_configs : name => {
      for dev, t in devs : dev => {
        read_bytes_sec  = t.read_bytes_sec == null ? null : t.read_bytes_sec * local._byte_units[coalesce(t.read_bytes_sec_unit, t.bytes_unit, "B")]
        write_bytes_sec = t.write_bytes_sec == null ? null : t.write_bytes_sec * local._byte_units[coalesce(t.write_bytes_sec_unit, t.bytes_unit, "B")]
        read_iops_sec   = t.read_iops_sec
        write_iops_sec  = t.write_iops_sec

        read_bytes_sec_max         = t.read_bytes_sec_max == null ? null : t.read_bytes_sec_max * local._byte_units[coalesce(t.read_bytes_sec_max_unit, t.bytes_unit, "B")]
        read_bytes_sec_max_length  = t.read_bytes_sec_max_length
        write_bytes_sec_max        = t.write_bytes_sec_max == null ? null : t.write_bytes_sec_max * local._byte_units[coalesce(t.write_bytes_sec_max_unit, t.bytes_unit, "B")]
        write_bytes_sec_max_length = t.write_bytes_sec_max_length
        read_iops_sec_max          = t.read_iops_sec_max
        read_iops_sec_max_length   = t.read_iops_sec_max_length
        write_iops_sec_max         = t.write_iops_sec_max
        write_iops_sec_max_length  = t.write_iops_sec_max_length
      }
    }
  }

  # --------------------------------------------------------------------------
  # Network — convert rate_unit (KB/MB/GB) to KiB (libvirt's native unit).
  # --------------------------------------------------------------------------
  network_normalized = {
    for name, ifaces in var.network_configs : name => {
      for iface, cfg in ifaces : iface => {
        inbound = cfg.inbound == null ? null : {
          average = cfg.inbound.average == null ? null : cfg.inbound.average * local._net_units[coalesce(cfg.inbound.average_unit, cfg.rate_unit, "KB")]
          peak    = cfg.inbound.peak == null ? null : cfg.inbound.peak * local._net_units[coalesce(cfg.inbound.peak_unit, cfg.rate_unit, "KB")]
          burst   = cfg.inbound.burst == null ? null : cfg.inbound.burst * local._net_units[coalesce(cfg.inbound.burst_unit, cfg.rate_unit, "KB")]
          floor   = cfg.inbound.floor == null ? null : cfg.inbound.floor * local._net_units[coalesce(cfg.inbound.floor_unit, cfg.rate_unit, "KB")]
        }
        outbound = cfg.outbound == null ? null : {
          average = cfg.outbound.average == null ? null : cfg.outbound.average * local._net_units[coalesce(cfg.outbound.average_unit, cfg.rate_unit, "KB")]
          peak    = cfg.outbound.peak == null ? null : cfg.outbound.peak * local._net_units[coalesce(cfg.outbound.peak_unit, cfg.rate_unit, "KB")]
          burst   = cfg.outbound.burst == null ? null : cfg.outbound.burst * local._net_units[coalesce(cfg.outbound.burst_unit, cfg.rate_unit, "KB")]
          floor   = cfg.outbound.floor == null ? null : cfg.outbound.floor * local._net_units[coalesce(cfg.outbound.floor_unit, cfg.rate_unit, "KB")]
        }
      }
    }
  }

  _any_file = length(var.cpu_configs) + length(var.disk_configs) + length(var.network_configs) > 0
}

# ----------------------------------------------------------------------------
# CPU files — one per entry in cpu_configs.
# ----------------------------------------------------------------------------
resource "local_file" "cpu" {
  for_each = var.cpu_configs

  filename        = "${var.output_dir}/.qv-limits/${var.prefix}-cpu-${each.key}.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/cpu.ini.tmpl", {
    name         = each.key
    generated_at = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())
    cpu_limit    = local.cpu_normalized[each.key]
  })
}

# ----------------------------------------------------------------------------
# Disk files — one per entry in disk_configs (may cover multiple devs inside).
# ----------------------------------------------------------------------------
resource "local_file" "disk" {
  for_each = var.disk_configs

  filename        = "${var.output_dir}/.qv-limits/${var.prefix}-disk-${each.key}.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/disk.ini.tmpl", {
    name         = each.key
    generated_at = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())
    devices      = local.disk_normalized[each.key]
  })
}

# ----------------------------------------------------------------------------
# Network files — one per entry in network_configs (may cover multiple ifaces).
# ----------------------------------------------------------------------------
resource "local_file" "network" {
  for_each = var.network_configs

  filename        = "${var.output_dir}/.qv-limits/${var.prefix}-network-${each.key}.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/network.ini.tmpl", {
    name         = each.key
    generated_at = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())
    interfaces   = local.network_normalized[each.key]
  })
}

# .gitignore so the .qv-limits dir doesn't accidentally get committed.
resource "local_file" "gitignore" {
  count = local._any_file ? 1 : 0

  filename        = "${var.output_dir}/.qv-limits/.gitignore"
  file_permission = "0644"
  content         = "# Generated by quick-throttle — do not commit\n*\n!.gitignore\n"
}
