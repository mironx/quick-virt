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
    user_name = coalesce(var.vm_profile.user_name, null)
    network_desc_order = coalesce(var.vm_profile.network_desc_order, false)
  }
  current_local_network = {
    ip = try(coalesce(var.local_network.ip,""),"")
    is_enabled = coalesce(var.local_network.is_enabled, true)
    profile = coalesce(var.local_network.is_enabled, true) ? {
      dhcp_mode   = coalesce(var.local_network.profile.dhcp_mode, "dhcp")
      mask        = try(coalesce(var.local_network.profile.mask, null),"")
      gateway4    = try(coalesce(var.local_network.profile.gateway4, null),"")
      nameservers = coalesce(var.local_network.profile.nameservers, [])
    } : {
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
      dhcp_mode = coalesce(var.bridge_network.profile.dhcp_mode, "dhcp")
      mask = try(coalesce(var.bridge_network.profile.mask, null),"")
      gateway4 = try(coalesce(var.bridge_network.profile.gateway4, null),"")
      nameservers = coalesce(var.bridge_network.profile.nameservers, [])
      bridge = coalesce(var.bridge_network.profile.bridge, "")
    } : {
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
#       error_message = jsonencode(local.current_local_network)
#     }
#   }
# }



//-------------------------------------------------------------------------------
locals {
  local_network_name = "local-network"
  bridge_network_name = "bridge-network"
  local_dhcp = local.current_local_network.is_enabled && local.current_local_network.profile.dhcp_mode == "dhcp"
  bridge_dhcp = local.current_bridge_network.is_enabled && local.current_bridge_network.profile.dhcp_mode == "dhcp"


  interface_network1 = "ens3"
  interface_network2 = local.current_local_network.is_enabled ? "ens4" : "ens3"
  user_password = trimspace(file("${path.module}/pswd"))

  network_config = templatefile("${path.module}/templates/network-config.tmpl", {
    interface_network1 = local.interface_network1
    local_is_enabled = local.current_local_network.is_enabled,
    local_network_ip = local.current_local_network.ip,
    local_network_mask = local.current_local_network.profile.mask,
    local_network_gateway4 = local.current_local_network.profile.gateway4,
    local_network_nameservers = local.current_local_network.profile.nameservers
    local_dhcp = local.local_dhcp


    interface_network2 = local.interface_network2
    bridge_is_enabled = local.current_bridge_network.is_enabled,
    bridge_network_ip = local.current_bridge_network.ip,
    bridge_network_mask = local.current_bridge_network.profile.mask,
    bridge_network_gateway4 = local.current_bridge_network.profile.gateway4,
    bridge_network_nameservers = local.current_bridge_network.profile.nameservers
    bridge_dhcp = local.bridge_dhcp
  })

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    local_hostname  = var.name
    user_name = local.current_vm_profile.user_name
    user_password = local.user_password
  })

  meta_data = templatefile("${path.module}/templates/user-data.tmpl", {
    local_hostname  = var.name
    user_name = local.current_vm_profile.user_name
    user_password = local.user_password
  })
}

//-------------------------------------------------------------------------------

resource "libvirt_volume" "vm-disk" {
  name   = "${var.name}.qcow2"
  pool   = "default"
  source = local.current_vm_profile.image_source
  format = "qcow2"
  depends_on = [null_resource.validate]
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.name}_cloudinit.iso"
  network_config = local.network_config
  user_data      = local.user_data
  meta_data      = local.meta_data
  pool           = "default"
  depends_on = [null_resource.validate]
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
      network_name = local.local_network_name
    }
  }

  dynamic "network_interface" {
    for_each = !local.current_vm_profile.network_desc_order && local.current_bridge_network.is_enabled ? [1] : []
    content {
      network_name = local.bridge_network_name
      bridge = local.current_bridge_network.profile.bridge
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
      bridge = local.current_bridge_network.profile.bridge
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
  # why we have double console (it is some bug in cloud init)

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

  depends_on = [
    libvirt_volume.vm-disk,
    libvirt_cloudinit_disk.cloudinit,
  ]
}