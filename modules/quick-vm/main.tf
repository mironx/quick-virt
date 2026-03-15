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

module "local_network_profile_reader" {
  count            = var.local_network.profile_name != null && coalesce(var.local_network.is_enabled, true) ? 1 : 0
  source           = "../quick-kvm-network-reader"
  kvm_network_name = var.local_network.profile_name
}

module "bridge_network_profile_reader" {
  count            = var.bridge_network.profile_name != null && coalesce(var.bridge_network.is_enabled, true) ? 1 : 0
  source           = "../quick-kvm-network-reader"
  kvm_network_name = var.bridge_network.profile_name
}

locals {
  # profile_name has priority over profile
  _local_reader_profile = (
    length(module.local_network_profile_reader) > 0
    ? module.local_network_profile_reader[0].profile
    : null
  )
  _bridge_reader_profile = (
    length(module.bridge_network_profile_reader) > 0
    ? module.bridge_network_profile_reader[0].profile
    : null
  )

  resolved_local_network_profile = local._local_reader_profile != null ? local._local_reader_profile : (
    var.local_network.profile != null ? {
      kvm_network_name = try(var.local_network.profile.kvm_network_name, "")
      dhcp_mode        = try(var.local_network.profile.dhcp_mode, "dhcp")
      mask             = try(var.local_network.profile.mask, "")
      gateway4         = try(var.local_network.profile.gateway4, "")
      nameservers      = try(var.local_network.profile.nameservers, [])
      bridge           = null
      mode             = null
      error            = try(var.local_network.profile.error, "")
    } : null
  )

  resolved_bridge_network_profile = local._bridge_reader_profile != null ? local._bridge_reader_profile : (
    var.bridge_network.profile != null ? {
      kvm_network_name = try(var.bridge_network.profile.kvm_network_name, "")
      dhcp_mode        = try(var.bridge_network.profile.dhcp_mode, "dhcp")
      mask             = try(var.bridge_network.profile.mask, "")
      gateway4         = try(var.bridge_network.profile.gateway4, "")
      nameservers      = try(var.bridge_network.profile.nameservers, [])
      bridge           = try(var.bridge_network.profile.bridge, "")
      mode             = null
      error            = try(var.bridge_network.profile.error, "")
    } : null
  )
}

locals {
  current_vm_profile = {
    image_source = coalesce(var.vm_profile.image_source, "/var/lib/libvirt/images/ubuntu-2204.qcow2.base")
    vcpu = coalesce(var.vm_profile.vcpu, null)
    memory = coalesce(var.vm_profile.memory, null)
    network_desc_order = coalesce(var.vm_profile.network_desc_order, false)
    cpu = var.vm_profile.cpu != null ? {
      mode = var.vm_profile.cpu.mode
    } : {
      mode = null
    }
  }
  validated_user_data = yamldecode(var.user_data)
  current_local_network = {
    ip = try(coalesce(var.local_network.ip,""),"")
    is_enabled = coalesce(var.local_network.is_enabled, true)
    profile = coalesce(var.local_network.is_enabled, true) ? {
      kvm_network_name = try(coalesce(local.resolved_local_network_profile.kvm_network_name, null),"")
      dhcp_mode   = coalesce(local.resolved_local_network_profile.dhcp_mode, "dhcp")
      mask        = try(coalesce(local.resolved_local_network_profile.mask, null),"")
      gateway4    = try(coalesce(local.resolved_local_network_profile.gateway4, null),"")
      nameservers = coalesce(local.resolved_local_network_profile.nameservers, [])
    } : {
      kvm_network_name = "?"
      dhcp_mode   = "?"
      mask        = "?"
      gateway4    = "?"
      nameservers = ["?"]
    }
  }

  current_bridge_network = {
    ip = try(coalesce(var.bridge_network.ip,""),"?")
    is_enabled = coalesce(var.bridge_network.is_enabled, true)
    profile = coalesce(var.bridge_network.is_enabled, true) ? {
      kvm_network_name = try(coalesce(local.resolved_bridge_network_profile.kvm_network_name, null),"")
      dhcp_mode = coalesce(local.resolved_bridge_network_profile.dhcp_mode, "dhcp")
      mask = try(coalesce(local.resolved_bridge_network_profile.mask, null),"")
      gateway4 = try(coalesce(local.resolved_bridge_network_profile.gateway4, null),"")
      nameservers = coalesce(local.resolved_bridge_network_profile.nameservers, [])
      bridge = coalesce(local.resolved_bridge_network_profile.bridge, "")
    } : {
      kvm_network_name = "?"
      dhcp_mode   = "?"
      mask        = "?"
      gateway4    = "?"
      nameservers = ["?"]
      bridge      = "?"
    }
  }
}


# resource "null_resource" "debug_local_network" {
#   triggers = {
#     always_run = timestamp()
#   }
#   lifecycle {
#     precondition {
#       condition = local.current_local_network == null
#       //error_message = jsonencode(var.local_network)
#       //error_message = jsonencode(local.current_local_network)
#       //error_message = "cpu.mode=${var.vm_profile.cpu.mode}"
#       error_message = "size=${var.main_storage.size} ${var.name}"
#     }
#   }
# }

//-------------------------------------------------------------------------------
locals {
  local_dhcp  = local.current_local_network.is_enabled && local.current_local_network.profile.dhcp_mode == "dhcp"
  bridge_dhcp = local.current_bridge_network.is_enabled && local.current_bridge_network.profile.dhcp_mode == "dhcp"


  interface_network1 = "enp0s3"
  interface_network2 = local.current_local_network.is_enabled ? "enp0s4" : "enp0s3"

  network_config = templatefile("${path.module}/templates/network-config.tmpl", {
    interface_network1        = local.interface_network1
    local_is_enabled          = local.current_local_network.is_enabled,
    local_network_ip          = local.current_local_network.ip,
    local_network_mask        = local.current_local_network.profile.mask,
    local_network_gateway4    = local.current_local_network.profile.gateway4,
    local_network_nameservers = local.current_local_network.profile.nameservers
    local_dhcp                = local.local_dhcp


    interface_network2         = local.interface_network2
    bridge_is_enabled          = local.current_bridge_network.is_enabled,
    bridge_network_ip          = local.current_bridge_network.ip,
    bridge_network_mask        = local.current_bridge_network.profile.mask,
    bridge_network_gateway4    = local.current_bridge_network.profile.gateway4,
    bridge_network_nameservers = local.current_bridge_network.profile.nameservers
    bridge_dhcp                = local.bridge_dhcp
  })

  user_data = replace(var.user_data, "HOST_NAME", var.name)

  meta_data = templatefile("${path.module}/templates/meta-data.tmpl", {
    instance_id    = var.name
    local_hostname = var.name
  })

  running     = var.running
  autostart   = var.autostart
  description = var.description
  storage_pool = var.storage_pool
}

locals {
  // Enable guest agent if the user_data contains "qemu-guest-agent"
  enable_guest_agent = can(regex("qemu-guest-agent", local.user_data))
}
//-------------------------------------------------------------------------------

locals {
  main_storage = var.main_storage != null ? {
    size = coalesce(var.main_storage.size, 20)
  } : {
    size         = 20
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

locals {
  # Build ordered list of network interfaces
  _local_interface = local.current_local_network.is_enabled ? [{
    source = {
      network = {
        network = local.current_local_network.profile.kvm_network_name
      }
    }
    model = {
      type = "virtio"
    }
  }] : []

  _bridge_interface = local.current_bridge_network.is_enabled ? [{
    source = {
      bridge = {
        bridge = local.current_bridge_network.profile.bridge
      }
    }
    model = {
      type = "virtio"
    }
  }] : []

}

resource "libvirt_domain" "vm" {
  name   = var.name
  type   = "kvm"
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
        device   = "cdrom"
        read_only = true
      }
    ]

    interfaces = local.current_vm_profile.network_desc_order ? concat(
      [for i in local._bridge_interface : i],
      [for i in local._local_interface : i]
    ) : concat(
      [for i in local._local_interface : i],
      [for i in local._bridge_interface : i]
    )

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