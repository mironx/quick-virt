terraform {
 required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

//-------------------------------------------------------------------------------
locals {
  local_network_name = "local-network"
  bridge_network_name = "bridge-network"
  local_dhcp = var.local_network_configuration.is_enabled && var.local_network_configuration.dhcp_mode == "dhcp"
  bridge_dhcp = var.bridge_network_configuration.is_enabled && var.bridge_network_configuration.dhcp_mode == "dhcp"


  interface_network1 = "ens3"
  interface_network2 = var.local_network_configuration.is_enabled ? "ens4" : "ens3"
  user_password = trimspace(file("${path.module}/pswd"))

  network_config = templatefile("${path.module}/templates/network-config.tmpl", {
    interface_network1 = local.interface_network1
    local_is_enabled = var.local_network_configuration.is_enabled,
    local_network_ip = var.local_network_configuration.ip,
    local_network_mask = var.local_network_configuration.mask,
    local_network_gateway4 = var.local_network_configuration.gateway4,
    local_network_nameservers = var.local_network_configuration.nameservers
    local_dhcp = local.local_dhcp


    interface_network2 = local.interface_network2
    bridge_is_enabled = var.bridge_network_configuration.is_enabled,
    bridge_network_ip = var.bridge_network_configuration.ip,
    bridge_network_mask = var.bridge_network_configuration.mask,
    bridge_network_gateway4 = var.bridge_network_configuration.gateway4,
    bridge_network_nameservers = var.bridge_network_configuration.nameservers
    bridge_dhcp = local.bridge_dhcp
  })

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    local_hostname  = var.vm.name
    user_name = var.vm.user_name
    user_password = local.user_password
  })

  meta_data = templatefile("${path.module}/templates/user-data.tmpl", {
    local_hostname  = var.vm.name
    user_name = var.vm.user_name
    user_password = local.user_password
  })
}

//-------------------------------------------------------------------------------

resource "libvirt_volume" "vm-disk" {
  name   = "${var.vm.name}.qcow2"
  pool   = "default"
  source = var.vm.image_source
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm.name}_cloudinit.iso"
  network_config = local.network_config
  user_data      = local.user_data
  meta_data      = local.meta_data
  pool           = "default"
}

resource "libvirt_domain" "vm" {
  name   = var.vm.name
  memory = var.vm.memory
  vcpu   = var.vm.vcpu

  disk {
    volume_id = libvirt_volume.vm-disk.id
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit.id

  # ------------------------------------------------------------------------------------------
  # Network interfaces are ordered differently based on network_desc_order variable
  # If network_desc_order is false, local network interface is first
  # If network_desc_order is true, bridge network interface is first
  dynamic "network_interface" {
    for_each = !var.vm.network_desc_order && var.local_network_configuration.is_enabled ? [1] : []
    content {
      network_name = local.local_network_name
    }
  }

  dynamic "network_interface" {
    for_each = !var.vm.network_desc_order && var.bridge_network_configuration.is_enabled ? [1] : []
    content {
      network_name = local.bridge_network_name
      bridge = "br0"
    }
  }
  # ------------------------------------------------------------------------------------------

  # ------------------------------------------------------------------------------------------
  # Reversed order when network_desc_order is true
  # If network_desc_order is true, bridge network interface is first
  # If network_desc_order is false, local network interface is first
  dynamic "network_interface" {
    for_each = var.vm.network_desc_order && var.bridge_network_configuration.is_enabled ? [1] : []
    content {
      network_name = local.bridge_network_name
      bridge = "br0"
    }
  }

  dynamic "network_interface" {
    for_each = var.vm.network_desc_order && var.local_network_configuration.is_enabled ? [1] : []
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


output "network_config_rendered" {
  value = local.network_config
  sensitive = false  # Ustaw na true, jeśli zawiera wrażliwe dane
}