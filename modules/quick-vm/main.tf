terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

//-------------------------------------------------------------------------------
// OS profiles
//-------------------------------------------------------------------------------

locals {
  os_profiles = {
    ubuntu_22 = {
      image_local      = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
      image_url        = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      network_template = "netplan"
      interface_naming = "enp0s"
      interface_offset = 3
      fs_type          = "virtiofs"
    }
    ubuntu_24 = {
      image_local      = "/var/lib/libvirt/images/ubuntu-2404.qcow2.base"
      image_url        = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      network_template = "netplan"
      interface_naming = "enp0s"
      interface_offset = 3
      fs_type          = "virtiofs"
    }
    rocky_9 = {
      image_local      = "/var/lib/libvirt/images/rocky-9.qcow2.base"
      image_url        = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
      network_template = "networkmanager"
      interface_naming = "eth"
      interface_offset = 0
      fs_type          = "virtiofs"
    }
    debian_12 = {
      image_local      = "/var/lib/libvirt/images/debian-12.qcow2.base"
      image_url        = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      network_template = "netplan"
      interface_naming = "enp0s"
      interface_offset = 3
      fs_type          = "virtiofs"
    }
  }

  # Resolve OS: os_volume > os_profile > os_name > default ubuntu_22
  _builtin_os = local.os_profiles[coalesce(var.os_name, "ubuntu_22")]

  # Priority: os_volume > os_profile > os_name > default ubuntu_22
  selected_os = var.os_volume != null ? var.os_volume.os_profile : (
    var.os_profile != null ? {
      image            = var.os_profile.image
      network_template = var.os_profile.network_template
      interface_naming = var.os_profile.interface_naming
      interface_offset = try(var.os_profile.interface_offset, 3)
      fs_type          = try(var.os_profile.fs_type, "virtiofs")
    } : {
      image            = var.os_image_mode == "local" ? local._builtin_os.image_local : local._builtin_os.image_url
      network_template = local._builtin_os.network_template
      interface_naming = local._builtin_os.interface_naming
      interface_offset = local._builtin_os.interface_offset
      fs_type          = local._builtin_os.fs_type
    }
  )
}

//-------------------------------------------------------------------------------
// Networks: filter enabled, read profiles, resolve
//-------------------------------------------------------------------------------

locals {
  # If kvm-networks is provided, use it to determine enabled state; otherwise use per-network enabled field
  _has_kvm_networks = length(var.kvm-networks) > 0

  enabled_networks = [
    for n in var.networks : n
    if local._has_kvm_networks ? try(var.kvm-networks[n.profile_name].enabled, false) : n.enabled
  ]

  # Resolve kvm-networks profile override: kvm-networks profile > per-network profile
  _networks_with_kvm_profile = [
    for n in local.enabled_networks : merge(n, {
      profile = (
        local._has_kvm_networks && try(var.kvm-networks[n.profile_name].profile, null) != null
        ? {
          kvm_network_name = try(var.kvm-networks[n.profile_name].profile.kvm_network_name, n.profile_name)
          dhcp_mode        = try(var.kvm-networks[n.profile_name].profile.dhcp_mode, "static")
          gateway4         = var.kvm-networks[n.profile_name].profile.gateway4
          mask             = var.kvm-networks[n.profile_name].profile.mask
          nameservers      = var.kvm-networks[n.profile_name].profile.nameservers
          bridge           = try(var.kvm-networks[n.profile_name].profile.bridge, null)
          error            = ""
        }
        : n.profile
      )
    })
  ]

  # Networks that need reader (profile_name set, no manual profile resolved)
  networks_needing_reader = {
    for idx, n in local._networks_with_kvm_profile :
    tostring(idx) => n.profile_name
    if n.profile_name != null && n.profile == null
  }
}

module "network_profile_reader" {
  for_each         = local.networks_needing_reader
  source           = "../quick-kvm-network-reader"
  kvm_network_name = each.value
}

locals {
  # Resolve profiles: manual profile > reader > null
  # Normalize all profiles to the same object shape to avoid type mismatches
  resolved_networks = [
    for idx, n in local._networks_with_kvm_profile : {
      ip           = try(coalesce(n.ip, ""), "")
      profile_name = n.profile_name
      profile = n.profile != null ? {
        kvm_network_name = try(n.profile.kvm_network_name, n.profile_name)
        dhcp_mode        = try(n.profile.dhcp_mode, "static")
        gateway4         = n.profile.gateway4
        mask             = n.profile.mask
        nameservers      = tolist(n.profile.nameservers)
        bridge           = try(n.profile.bridge, null)
        error            = try(n.profile.error, "")
        mode             = try(n.profile.mode, null)
      } : (
        contains(keys(local.networks_needing_reader), tostring(idx))
        ? {
          kvm_network_name = module.network_profile_reader[tostring(idx)].profile.kvm_network_name
          dhcp_mode        = module.network_profile_reader[tostring(idx)].profile.dhcp_mode
          gateway4         = module.network_profile_reader[tostring(idx)].profile.gateway4
          mask             = module.network_profile_reader[tostring(idx)].profile.mask
          nameservers      = tolist(module.network_profile_reader[tostring(idx)].profile.nameservers)
          bridge           = module.network_profile_reader[tostring(idx)].profile.bridge
          error            = module.network_profile_reader[tostring(idx)].profile.error
          mode             = module.network_profile_reader[tostring(idx)].profile.mode
        }
        : null
      )
    }
  ]
}

//-------------------------------------------------------------------------------
// VM profile
//-------------------------------------------------------------------------------

locals {
  current_vm_profile = {
    vcpu   = coalesce(var.vm_profile.vcpu, null)
    memory = coalesce(var.vm_profile.memory, null)
    cpu = {
      mode = try(var.vm_profile.cpu.mode, "host-passthrough")
    }
  }

  validated_user_data = yamldecode(var.user_data)

}

//-------------------------------------------------------------------------------
// Network config for cloud-init
//-------------------------------------------------------------------------------

locals {
  network_config = templatefile(
    "${path.module}/templates/network-config-${local.selected_os.network_template}.tmpl",
    {
      networks = [
        for idx, n in local.resolved_networks : {
          # For PCI-slot-based naming (enp0s*): shared_folders (9p filesystems) occupy
          # PCI slots before network interfaces, shifting slot numbers by +1 per folder.
          # For kernel-order naming (eth*): slot position doesn't affect naming.
          interface = "${local.selected_os.interface_naming}${idx + local.selected_os.interface_offset + (
            local.selected_os.interface_naming == "eth" ? 0 : length(var.shared_folders)
          )}"
          ip          = n.ip
          mask        = try(n.profile.mask, "")
          gateway4    = try(n.profile.gateway4, "")
          nameservers = try(n.profile.nameservers, [])
          dhcp        = try(n.profile.dhcp_mode, "static") == "dhcp"
        }
      ]
    }
  )

  # Priority: var.fs_type > os_profile.fs_type > os_name builtin
  fs_type = coalesce(var.fs_type, local.selected_os.fs_type)

  # Cloud-init multipart MIME fragments (in order):
  # 1. hostname (always, auto-generated)
  # 2. run_before (optional — commands before user_data)
  # 3. user_data (user template — users, packages, base runcmd)
  # 4. shared-folders (auto, if shared_folders > 0 — modprobe, mkdir, mount virtiofs/9p)
  # 5. nfs-mounts (auto, if nfs_mounts > 0 — install nfs client, mkdir, mount -a)
  # 6. run_after (optional — commands after shared folders/nfs mount)
  # 7. user_data_after (optional — full cloud-config after everything)

  _mime_hostname = templatefile("${path.module}/templates/cloud-config-hostname.tmpl", {
    hostname = var.name
  })

  _mime_run_before = length(var.run_before) > 0 ? templatefile(
    "${path.module}/templates/cloud-config-runcmd.tmpl", {
      commands = var.run_before
    }
  ) : ""

  _mime_shared_folders = length(var.shared_folders) > 0 ? templatefile(
    "${path.module}/templates/cloud-config-shared-folders.tmpl", {
      shared_folders = var.shared_folders
      fs_type        = local.fs_type
    }
  ) : ""

  # NFS package: rocky_9 → nfs-utils, everything else → nfs-common
  _nfs_package = (
    coalesce(var.os_name, try(var.os_volume.os_name, "ubuntu_22")) == "rocky_9"
    ? "nfs-utils"
    : "nfs-common"
  )

  _mime_nfs_mounts = length(var.nfs_mounts) > 0 ? templatefile(
    "${path.module}/templates/cloud-config-nfs-mounts.tmpl", {
      nfs_mounts  = var.nfs_mounts
      nfs_package = local._nfs_package
    }
  ) : ""

  _mime_run_after = length(var.run_after) > 0 ? templatefile(
    "${path.module}/templates/cloud-config-runcmd.tmpl", {
      commands = var.run_after
    }
  ) : ""

  _mime_parts = concat(
    [
      { filename = "hostname.cfg", content = trimspace(local._mime_hostname) },
    ],
    length(var.run_before) > 0 ? [
      { filename = "run-before.cfg", content = trimspace(local._mime_run_before) },
    ] : [],
    [
      { filename = "base.cfg", content = trimspace(var.user_data) },
    ],
    length(var.shared_folders) > 0 ? [
      { filename = "shared-folders.cfg", content = trimspace(local._mime_shared_folders) },
    ] : [],
    length(var.nfs_mounts) > 0 ? [
      { filename = "nfs-mounts.cfg", content = trimspace(local._mime_nfs_mounts) },
    ] : [],
    length(var.run_after) > 0 ? [
      { filename = "run-after.cfg", content = trimspace(local._mime_run_after) },
    ] : [],
    var.user_data_after != null ? [
      { filename = "after.cfg", content = trimspace(var.user_data_after) },
    ] : [],
  )

  # Always use multipart MIME — hostname is always a separate fragment
  user_data = join("\n", concat(
    [
      "Content-Type: multipart/mixed; boundary=\"MIMEBOUNDARY\"",
      "MIME-Version: 1.0",
      "",
    ],
    flatten([
      for part in local._mime_parts : [
        "--MIMEBOUNDARY",
        "Content-Type: text/cloud-config; charset=\"us-ascii\"",
        "Content-Disposition: attachment; filename=\"${part.filename}\"",
        "",
        part.content,
        "",
      ]
    ]),
    ["--MIMEBOUNDARY--"],
  ))

  meta_data = templatefile("${path.module}/templates/meta-data.tmpl", {
    instance_id    = var.name
    local_hostname = var.name
  })

  running      = var.running
  autostart    = var.autostart
  description  = var.description
  storage_pool = var.os_volume != null ? var.os_volume.pool : var.storage_pool
}

locals {
  // Enable guest agent if the user_data contains "qemu-guest-agent"
  enable_guest_agent = can(regex("qemu-guest-agent", local.user_data))
}

//-------------------------------------------------------------------------------
// Storage
//-------------------------------------------------------------------------------

locals {
  main_storage = var.main_storage != null ? {
    size = coalesce(var.main_storage.size, 20)
  } : {
    size = 20
  }
  main_storage_size = local.main_storage.size * 1024 * 1024 * 1024
}

# Per-VM reference volume — only for backing_store without os_volume
resource "libvirt_volume" "vm-disk-reference" {
  count = var.os_volume == null && var.os_disk_mode == "backing_store" ? 1 : 0
  name  = "${var.name}-ref.qcow2"
  pool  = local.storage_pool
  create = {
    content = {
      url = local.selected_os.image
    }
  }
  target = {
    format = {
      type = "qcow2"
    }
  }
}

locals {
  # Base image path for backing_store only (clone uses selected_os.image directly)
  base_image_path = (
    var.os_disk_mode == "clone"
    ? null
    : var.os_volume != null
      ? var.os_volume.path
      : libvirt_volume.vm-disk-reference[0].path
  )
}

# backing_store mode: thin disk referencing base image
resource "libvirt_volume" "vm-disk-thin" {
  count    = var.os_disk_mode == "backing_store" ? 1 : 0
  name     = "${var.name}.qcow2"
  pool     = local.storage_pool
  capacity = local.main_storage_size

  backing_store = {
    path = local.base_image_path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# clone mode: full independent copy directly from original image source
# Uses selected_os.image (local path or URL) — not the libvirt-managed reference volume
resource "libvirt_volume" "vm-disk-clone" {
  count    = var.os_disk_mode == "clone" ? 1 : 0
  name     = "${var.name}.qcow2"
  pool     = local.storage_pool
  capacity = local.main_storage_size

  create = {
    content = {
      url = local.selected_os.image
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

locals {
  vm_disk_name = var.os_disk_mode == "backing_store" ? libvirt_volume.vm-disk-thin[0].name : libvirt_volume.vm-disk-clone[0].name
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.name}_cloudinit"
  network_config = local.network_config
  user_data      = local.user_data
  meta_data      = local.meta_data
  depends_on     = [null_resource.validate]
}

resource "libvirt_volume" "cloudinit" {
  name = "${var.name}_cloudinit.iso"
  pool = local.storage_pool
  create = {
    content = {
      url = libvirt_cloudinit_disk.cloudinit.path
    }
  }
  target = {
    format = {
      type = "iso"
    }
  }
}

//-------------------------------------------------------------------------------
// Network interfaces for libvirt domain
//-------------------------------------------------------------------------------

locals {
  vm_interfaces = [
    for idx, n in local.resolved_networks : {
      source = try(n.profile.bridge, null) != null ? {
        bridge = {
          bridge = n.profile.bridge
        }
      } : {
        network = {
          network = try(n.profile.kvm_network_name, n.profile_name)
        }
      }
      model = {
        type = "virtio"
      }
      bandwidth = local.limits_enable_config && try(local.net_limits[tostring(idx)], null) != null ? {
        inbound  = local.net_limits[tostring(idx)].inbound
        outbound = local.net_limits[tostring(idx)].outbound
      } : null
    }
  ]
}

//-------------------------------------------------------------------------------
// Resource limits (CPU throttle + disk I/O throttle)
//-------------------------------------------------------------------------------

locals {
  _cpu_limit_raw = try(var.vm_profile.cpu.limit, null)

  _has_cpu_percent = try(local._cpu_limit_raw.percent, null) != null
  _has_cpu_raw     = try(local._cpu_limit_raw.quota_us, null) != null
  _has_cpu_shares  = try(local._cpu_limit_raw.shares, null) != null

  cpu_limit_enabled = local._cpu_limit_raw != null && (local._has_cpu_percent || local._has_cpu_raw || local._has_cpu_shares)

  _cpu_period = coalesce(try(local._cpu_limit_raw.period_us, null), 100000)
  _cpu_quota_from_percent = local._has_cpu_percent ? floor(var.vm_profile.vcpu * local._cpu_period * local._cpu_limit_raw.percent / 100) : null

  _cpu_user_set_period_us = try(local._cpu_limit_raw.period_us, null) != null
  _cpu_user_set_quota_us  = try(local._cpu_limit_raw.quota_us,  null) != null

  cpu_limit = local.cpu_limit_enabled ? {
    percent   = try(local._cpu_limit_raw.percent, null)
    period_us = local._cpu_period
    quota_us  = coalesce(try(local._cpu_limit_raw.quota_us, null), local._cpu_quota_from_percent, 0) == 0 ? null : coalesce(try(local._cpu_limit_raw.quota_us, null), local._cpu_quota_from_percent)
    shares    = try(local._cpu_limit_raw.shares, null)

    # Flags for INI template — did the user set raw values explicitly?
    _user_percent   = local._has_cpu_percent
    _user_period_us = local._cpu_user_set_period_us
    _user_quota_us  = local._cpu_user_set_quota_us
  } : null

  # Unit multipliers. Binary (1024-based) to match libvirt's internal KiB.
  _byte_units = {
    B  = 1
    KB = 1024
    MB = 1048576
    GB = 1073741824
  }

  # Normalize per-disk I/O throttles — convert byte fields to raw bytes using
  # per-field unit > disk-level bytes_unit > "B".
  _io_raw = try(var.vm_profile.io, null)
  io_limits = local._io_raw != null ? {
    for dev, t in local._io_raw : dev => {
      read_bytes_sec             = try(t.read_bytes_sec,  null) == null ? null : t.read_bytes_sec  * local._byte_units[coalesce(try(t.read_bytes_sec_unit,  null), try(t.bytes_unit, null), "B")]
      write_bytes_sec            = try(t.write_bytes_sec, null) == null ? null : t.write_bytes_sec * local._byte_units[coalesce(try(t.write_bytes_sec_unit, null), try(t.bytes_unit, null), "B")]
      read_iops_sec              = try(t.read_iops_sec,   null)
      write_iops_sec             = try(t.write_iops_sec,  null)
      read_bytes_sec_max         = try(t.read_bytes_sec_max,  null) == null ? null : t.read_bytes_sec_max  * local._byte_units[coalesce(try(t.read_bytes_sec_max_unit,  null), try(t.bytes_unit, null), "B")]
      read_bytes_sec_max_length  = try(t.read_bytes_sec_max_length,  null)
      write_bytes_sec_max        = try(t.write_bytes_sec_max, null) == null ? null : t.write_bytes_sec_max * local._byte_units[coalesce(try(t.write_bytes_sec_max_unit, null), try(t.bytes_unit, null), "B")]
      write_bytes_sec_max_length = try(t.write_bytes_sec_max_length, null)
      read_iops_sec_max          = try(t.read_iops_sec_max,  null)
      read_iops_sec_max_length   = try(t.read_iops_sec_max_length,  null)
      write_iops_sec_max         = try(t.write_iops_sec_max, null)
      write_iops_sec_max_length  = try(t.write_iops_sec_max_length, null)
    }
  } : {}

  # Network rate units — libvirt base is KiB (rates KiB/s, burst KiB).
  _net_units = {
    KB = 1
    MB = 1024
    GB = 1048576
  }

  _net_raw = try(var.vm_profile.network, null)

  net_limits = local._net_raw != null ? {
    for iface, cfg in local._net_raw : iface => {
      inbound = try(cfg.inbound, null) == null ? null : {
        average = try(cfg.inbound.average, null) == null ? null : cfg.inbound.average * local._net_units[coalesce(try(cfg.inbound.average_unit, null), try(cfg.rate_unit, null), "KB")]
        peak    = try(cfg.inbound.peak,    null) == null ? null : cfg.inbound.peak    * local._net_units[coalesce(try(cfg.inbound.peak_unit,    null), try(cfg.rate_unit, null), "KB")]
        burst   = try(cfg.inbound.burst,   null) == null ? null : cfg.inbound.burst   * local._net_units[coalesce(try(cfg.inbound.burst_unit,   null), try(cfg.rate_unit, null), "KB")]
        floor   = try(cfg.inbound.floor,   null) == null ? null : cfg.inbound.floor   * local._net_units[coalesce(try(cfg.inbound.floor_unit,   null), try(cfg.rate_unit, null), "KB")]
      }
      outbound = try(cfg.outbound, null) == null ? null : {
        average = try(cfg.outbound.average, null) == null ? null : cfg.outbound.average * local._net_units[coalesce(try(cfg.outbound.average_unit, null), try(cfg.rate_unit, null), "KB")]
        peak    = try(cfg.outbound.peak,    null) == null ? null : cfg.outbound.peak    * local._net_units[coalesce(try(cfg.outbound.peak_unit,    null), try(cfg.rate_unit, null), "KB")]
        burst   = try(cfg.outbound.burst,   null) == null ? null : cfg.outbound.burst   * local._net_units[coalesce(try(cfg.outbound.burst_unit,   null), try(cfg.rate_unit, null), "KB")]
        floor   = try(cfg.outbound.floor,   null) == null ? null : cfg.outbound.floor   * local._net_units[coalesce(try(cfg.outbound.floor_unit,   null), try(cfg.rate_unit, null), "KB")]
      }
    }
  } : {}

  limits_enable_config = try(var.vm_profile.enable_config, true)
  limits_enable_live   = try(var.vm_profile.enable_live, false)

  has_any_limit = local.cpu_limit_enabled || length(local.io_limits) > 0 || length(local.net_limits) > 0

  # ----------------------- Native provider attrs (enable_config = true) -----------------------
  # cpu_tune payload for libvirt_domain.cpu_tune (omit when limits disabled)
  native_cpu_tune = local.limits_enable_config && local.cpu_limit_enabled ? {
    period = local.cpu_limit.period_us
    quota  = local.cpu_limit.quota_us
    shares = local.cpu_limit.shares
  } : null

  # Per-disk io_tune — goes INSIDE disks[*] (supports baseline + burst natively
  # on qcow2 files). For v1 we throttle only the main disk (target dev='vda').
  _io_vda = try(local.io_limits["vda"], null)
  native_io_tune_vda = local.limits_enable_config && local._io_vda != null ? {
    read_bytes_sec             = local._io_vda.read_bytes_sec
    write_bytes_sec            = local._io_vda.write_bytes_sec
    read_iops_sec              = local._io_vda.read_iops_sec
    write_iops_sec             = local._io_vda.write_iops_sec
    read_bytes_sec_max         = local._io_vda.read_bytes_sec_max
    read_bytes_sec_max_length  = local._io_vda.read_bytes_sec_max_length
    write_bytes_sec_max        = local._io_vda.write_bytes_sec_max
    write_bytes_sec_max_length = local._io_vda.write_bytes_sec_max_length
    read_iops_sec_max          = local._io_vda.read_iops_sec_max
    read_iops_sec_max_length   = local._io_vda.read_iops_sec_max_length
    write_iops_sec_max         = local._io_vda.write_iops_sec_max
    write_iops_sec_max_length  = local._io_vda.write_iops_sec_max_length
  } : null

  # ----------------------- Sidecar files (for enable_live = true) -----------------------
  limits_ini = local.has_any_limit && local.limits_enable_live ? templatefile(
    "${path.module}/templates/limits-spec.ini.tmpl",
    {
      vm_name            = var.name
      vcpu               = var.vm_profile.vcpu
      generated_at       = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())
      quick_virt_version = "dev"
      enable_config      = local.limits_enable_config
      enable_live        = local.limits_enable_live
      cpu_limit          = local.cpu_limit
      io_limits          = local.io_limits
      net_limits         = local.net_limits
    }
  ) : ""

  limits_sh = local.has_any_limit && local.limits_enable_live ? templatefile(
    "${path.module}/templates/limits-apply.sh.tmpl",
    {
      vm_name    = var.name
      cpu_limit  = local.cpu_limit
      io_limits  = local.io_limits
      net_limits = local.net_limits
    }
  ) : ""

  # Clear-all counterpart — emitted whenever enable_live is on, independent of
  # whether limits are currently configured. Handy to roll back an experiment.
  limits_sh_clear = local.limits_enable_live ? templatefile(
    "${path.module}/templates/limits-clear.sh.tmpl",
    {
      vm_name = var.name
    }
  ) : ""
}

//-------------------------------------------------------------------------------
// Domain
//-------------------------------------------------------------------------------

resource "libvirt_domain" "vm" {
  name        = var.name
  type        = "kvm"
  memory      = local.current_vm_profile.memory
  memory_unit = "MiB"
  vcpu        = local.current_vm_profile.vcpu

  memory_backing = {
    memory_access = {
      mode = var.memory_backing.shared ? "shared" : "private"
    }
    memory_source = var.memory_backing.source != null ? {
      type = var.memory_backing.source
    } : null
    memory_locked       = var.memory_backing.locked
    memory_discard      = var.memory_backing.discard
    memory_nosharepages = var.memory_backing.nosharepages
  }

  os = {
    type = "hvm"
    boot = [{
      dev = "hd"
    }]
  }

  cpu = {
    mode = local.current_vm_profile.cpu.mode
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = local.storage_pool
            volume = local.vm_disk_name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        io_tune = local.native_io_tune_vda
      },
      {
        source = {
          volume = {
            pool   = local.storage_pool
            volume = libvirt_volume.cloudinit.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        device    = "cdrom"
        read_only = true
      }
    ]

    interfaces = [for i in local.vm_interfaces : i]

    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      },
      {
        target = {
          type = "virtio"
          port = 1
        }
      }
    ]

    graphics = [
      {
        spice = {
          auto_port = true
        }
      }
    ]

    channels = local.enable_guest_agent ? [
      {
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ] : []

    filesystems = [
      for f in var.shared_folders : {
        source = {
          mount = {
            dir = f.source
          }
        }
        target = {
          dir = f.target
        }
        read_only   = f.read_only
        access_mode = local.fs_type == "virtiofs" ? "passthrough" : "mapped"
        driver = {
          type = local.fs_type == "virtiofs" ? "virtiofs" : "path"
        }
      }
    ]
  }

  running     = local.running
  autostart   = local.autostart
  description = local.description

  cpu_tune = local.native_cpu_tune

  depends_on = [
    libvirt_volume.vm-disk-thin,
    libvirt_volume.vm-disk-clone,
    libvirt_volume.cloudinit,
  ]
}

//-------------------------------------------------------------------------------
// Sidecar limit files (enable_live)
//-------------------------------------------------------------------------------

resource "local_file" "limits_ini" {
  count           = local.limits_ini != "" ? 1 : 0
  filename        = "${path.root}/.qv-limits/qv-limits.spec.${var.name}.ini"
  content         = local.limits_ini
  file_permission = "0644"
}

resource "local_file" "limits_sh" {
  count           = local.limits_sh != "" ? 1 : 0
  filename        = "${path.root}/.qv-limits/qv-limits.apply.${var.name}.sh"
  content         = local.limits_sh
  file_permission = "0755"
}

resource "local_file" "limits_sh_clear" {
  count           = local.limits_sh_clear != "" ? 1 : 0
  filename        = "${path.root}/.qv-limits/qv-limits.clear.${var.name}.sh"
  content         = local.limits_sh_clear
  file_permission = "0755"
}

resource "local_file" "limits_gitignore" {
  count           = (local.limits_ini != "" || local.limits_sh != "" || local.limits_sh_clear != "") ? 1 : 0
  filename        = "${path.root}/.qv-limits/.gitignore"
  content         = "*\n!.gitignore\n"
  file_permission = "0644"
}
