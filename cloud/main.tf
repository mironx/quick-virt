terraform {
 required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "vm_name" {
  type = string
  default = "vm_test_1"
}

variable "vm_image_source"{
  type = string
  default = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
}

variable "vm_vcpu" {
  type = number
  default = 2
}

variable "vm_memory" {
  type = number
  default = 2048
}

variable "user_name" {
  type = string
  default = "devx"
}


// local_network_name = "local-network"
// local_network_addresses = ["192.168.100.0/24"]
variable "local_network_configuration" {
  type = object({
    is_enabled = bool
    name = string
    ip = string
    mask = string
    gateway4 = string
    nameservers = list(string)
  })
  default = {
    is_enabled = true
    name = "local-network"
    ip = "192.168.100.15"
    mask = "24"
    gateway4 = "192.168.100.1"
    nameservers = ["1.1.1.1", "8.8.8.8"]
  }
}


//-------------------------------------------------------------------------------
locals {
  user_password = trimspace(file("${path.module}/pswd"))

  network_config = templatefile("${path.module}/templates/network-config.tmpl", {
    is_enabled = var.local_network_configuration.is_enabled,
    local_network_ip = var.local_network_configuration.ip,
    local_network_mask = var.local_network_configuration.mask,
    local_network_gateway4 = var.local_network_configuration.gateway4,
    local_network_nameservers = var.local_network_configuration.nameservers
  })

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    local_hostname  = var.vm_name
    user_name = var.user_name
    user_password = local.user_password
  })

  meta_data = templatefile("${path.module}/templates/user-data.tmpl", {
    local_hostname  = var.vm_name
    user_name = var.user_name
    user_password = local.user_password
  })
}

//-------------------------------------------------------------------------------

resource "libvirt_volume" "vm-disk" {
  name   = "${var.vm_name}.qcow2"
  pool   = "default"
  source = var.vm_image_source
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm_name}_cloudinit.iso"
  network_config = local.network_config
  user_data      = local.user_data
  meta_data      = local.meta_data
  pool           = "default"
}

resource "libvirt_domain" "vm" {
  name   = var.vm_name
  memory = var.vm_memory
  vcpu   = var.vm_vcpu

  disk {    
    volume_id = libvirt_volume.vm-disk.id
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit.id

  dynamic "network_interface" {
    for_each = var.local_network_configuration.is_enabled ? [1] : []
    content {
      network_name = var.local_network_configuration.name
    }
  }

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