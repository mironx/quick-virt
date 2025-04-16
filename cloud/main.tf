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

variable "local_network_name" {
  type = string
  default = "local-network"
}

variable "user_name" {
  type = string
  default = "devx"
}

variable "user_password" {
  type = string
  default = "abc"
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
    user_password = var.user_password
  }
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm_name}_cloudinit.iso"
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
    network_name = var.local_network_name
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type = "spice"
    listen_type = "none"
  }
  
  depends_on = [    
    libvirt_volume.vm-disk,
    libvirt_cloudinit_disk.cloudinit,
  ]
}