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
  # 4. shared-folders (auto, if shared_folders > 0 — modprobe, mkdir, mount)
  # 5. run_after (optional — commands after shared folders mount)
  # 6. user_data_after (optional — full cloud-config after everything)

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
    }
  ]
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

  depends_on = [
    libvirt_volume.vm-disk-thin,
    libvirt_volume.vm-disk-clone,
    libvirt_volume.cloudinit,
  ]
}
