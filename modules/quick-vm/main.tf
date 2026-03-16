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
// Networks: filter enabled, read profiles, resolve
//-------------------------------------------------------------------------------

locals {
  enabled_networks = [for n in var.networks : n if n.enabled]

  # Networks that need reader (profile_name set, no manual profile)
  networks_needing_reader = {
    for idx, n in local.enabled_networks :
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
    for idx, n in local.enabled_networks : {
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
    image_source = coalesce(var.vm_profile.image_source, "/var/lib/libvirt/images/ubuntu-2204.qcow2.base")
    vcpu   = coalesce(var.vm_profile.vcpu, null)
    memory = coalesce(var.vm_profile.memory, null)
    cpu = var.vm_profile.cpu != null ? {
      mode = var.vm_profile.cpu.mode
    } : {
      mode = null
    }
  }

  validated_user_data = yamldecode(var.user_data)
}

//-------------------------------------------------------------------------------
// Network config for cloud-init
//-------------------------------------------------------------------------------

locals {
  network_config = templatefile("${path.module}/templates/network-config.tmpl", {
    networks = [
      for idx, n in local.resolved_networks : {
        interface = "enp0s${idx + 3}"
        ip        = n.ip
        mask      = try(n.profile.mask, "")
        gateway4  = try(n.profile.gateway4, "")
        nameservers = try(n.profile.nameservers, [])
        dhcp      = try(n.profile.dhcp_mode, "static") == "dhcp"
      }
    ]
  })

  user_data = replace(var.user_data, "HOST_NAME", var.name)

  meta_data = templatefile("${path.module}/templates/meta-data.tmpl", {
    instance_id    = var.name
    local_hostname = var.name
  })

  running      = var.running
  autostart    = var.autostart
  description  = var.description
  storage_pool = var.storage_pool
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

resource "libvirt_volume" "vm-disk-reference" {
  name = "${var.name}-ref.qcow2"
  pool = local.storage_pool
  create = {
    content = {
      url = local.current_vm_profile.image_source
    }
  }
  target = {
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "vm-disk" {
  name     = "${var.name}.qcow2"
  pool     = local.storage_pool
  capacity = local.main_storage_size

  backing_store = {
    path = libvirt_volume.vm-disk-reference.path
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
            volume = libvirt_volume.vm-disk.name
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
  }

  running     = local.running
  autostart   = local.autostart
  description = local.description

  depends_on = [
    libvirt_volume.vm-disk,
    libvirt_volume.cloudinit,
  ]
}