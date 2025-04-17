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
  default = "/var/lib/libvirt/images/ubuntu-2204.qcow2"
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
    name = string
    ip = string
    mask = string
    gateway4 = string
    nameservers = list(string)
  })
  default = {
    name = "local-network"
    ip = "192.168.100.13"
    mask = "24"
    gateway4 = "192.168.1.1"
    nameservers = ["1.1.1.1", "8.8.8.8"]
  }
}


//-------------------------------------------------------------------------------
locals {
  user_password = trimspace(file("${path.module}/pswd"))
}
//-------------------------------------------------------------------------------

resource "libvirt_volume" "vm-disk" {
  name   = "${var.vm_name}.qcow2"
  pool   = "default"
  source = var.vm_image_source
  format = "qcow2"
}


data "template_file" "meta_data" {
  template = file("${path.module}/templates/meta-data.tmpl")
  vars = {
    instance_id     = var.vm_name
    local_hostname  = var.vm_name
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.tmpl")
  vars = {
    local_hostname  = var.vm_name
    user_name = var.user_name
    user_password = local.user_password
  }
}

data "template_file" "network-config" {
  template =  file("${path.module}/templates/network-config.tmpl")
  vars = {
      ip = var.local_network_configuration.ip,
      mask = var.local_network_configuration.mask,
      gateway4 = var.local_network_configuration.gateway4
      nameservers = join("\n", [for ns in var.local_network_configuration.nameservers : "        - ${ns}"])
  }
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm_name}_cloudinit.iso"
  network_config = data.template_file.network-config.rendered
  user_data      = data.template_file.user_data.rendered
  meta_data      = data.template_file.meta_data.rendered
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

  network_interface {
    network_name = var.local_network_configuration.name
    addresses = [var.local_network_configuration.ip]
  }

  # see: https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf
  # why we have double console
  # it is some bug, it unblock creating network?

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