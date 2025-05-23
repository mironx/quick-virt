terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }
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
      kvm_network_name = try(coalesce(var.local_network.profile.kvm_network_name, null),"")
      dhcp_mode   = coalesce(var.local_network.profile.dhcp_mode, "dhcp")
      mask        = try(coalesce(var.local_network.profile.mask, null),"")
      gateway4    = try(coalesce(var.local_network.profile.gateway4, null),"")
      nameservers = coalesce(var.local_network.profile.nameservers, [])
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
      kvm_network_name = try(coalesce(var.bridge_network.profile.kvm_network_name, null),"")
      dhcp_mode = coalesce(var.bridge_network.profile.dhcp_mode, "dhcp")
      mask = try(coalesce(var.bridge_network.profile.mask, null),"")
      gateway4 = try(coalesce(var.bridge_network.profile.gateway4, null),"")
      nameservers = coalesce(var.bridge_network.profile.nameservers, [])
      bridge = coalesce(var.bridge_network.profile.bridge, "")
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


  interface_network1 = "ens3"
  interface_network2 = local.current_local_network.is_enabled ? "ens4" : "ens3"

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
  name   = "${var.name}-ref.qcow2"
  source = local.current_vm_profile.image_source
}

resource "libvirt_volume" "vm-disk" {
  name   = "${var.name}.qcow2"
  pool   = local.storage_pool
  format = "qcow2"
  base_volume_id = libvirt_volume.vm-disk-reference.id
  size   = local.main_storage_size
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.name}_cloudinit.iso"
  network_config = local.network_config
  user_data      = local.user_data
  meta_data      = local.meta_data
  pool           = local.storage_pool
  depends_on     = [null_resource.validate]
}

resource "libvirt_domain" "vm" {
  name   = var.name
  memory = local.current_vm_profile.memory
  vcpu   = local.current_vm_profile.vcpu

  disk {
    volume_id = libvirt_volume.vm-disk.id
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit.id

  # ------------------------------------------------------------------------------------------
  # Network interfaces are ordered differently based on network_desc_order variable
  # If network_desc_order is false, local network interface is first
  # If network_desc_order is true, bridge network interface is first
  dynamic "network_interface" {
    for_each = !local.current_vm_profile.network_desc_order && local.current_local_network.is_enabled ? [1] : []
    content {
      network_name = local.current_local_network.profile.kvm_network_name
    }
  }

  dynamic "network_interface" {
    for_each = !local.current_vm_profile.network_desc_order && local.current_bridge_network.is_enabled ? [1] : []
    content {
      network_name = local.current_bridge_network.profile.kvm_network_name
      bridge       = local.current_bridge_network.profile.bridge
    }
  }
  # ------------------------------------------------------------------------------------------

  # ------------------------------------------------------------------------------------------
  # Reversed order when network_desc_order is true
  # If network_desc_order is true, bridge network interface is first
  # If network_desc_order is false, local network interface is first
  dynamic "network_interface" {
    for_each = local.current_vm_profile.network_desc_order && local.current_bridge_network.is_enabled ? [1] : []
    content {
      network_name = local.bridge_network_name
      bridge       = local.current_bridge_network.profile.bridge
    }
  }

  dynamic "network_interface" {
    for_each = local.current_vm_profile.network_desc_order && local.current_local_network.is_enabled ? [1] : []
    content {
      network_name = local.local_network_name
    }
  }
  # ------------------------------------------------------------------------------------------

  # see: https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf
  # why we have double console (it is some bug in examples init)

  cpu {
    mode = local.current_vm_profile.cpu.mode
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  running = local.running
  autostart = local.autostart
  description = local.description


  qemu_agent = local.enable_guest_agent

  depends_on = [
    libvirt_volume.vm-disk,
    libvirt_cloudinit_disk.cloudinit,
  ]
}