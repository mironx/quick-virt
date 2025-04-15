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

variable "vm_instance_id" {
  type = string
  default = "vm_test_1"
}

variable "vm_local_hostname" {
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

variable "vm_local_network" {
  type = list(string)
  default = ["192.168.100.0/24"]
}

//-------------------------------------------------------------------------------

resource "libvirt_volume" "vm-disk" {
  name   = "${var.vm_name}.qcow2"
  pool   = "default"
  source = var.vm_image_source
  format = "qcow2"
}

resource "libvirt_network" "local-network" {
  name      = "terraform-net"
  mode      = "nat"
  domain    = "local"
  addresses = var.vm_local_network
  autostart = true
}

data "template_file" "meta_data" {
  template = file("${path.module}/meta-data.tmpl")
  vars = {
    instance_id     = var.vm_instance_id
    local_hostname  = var.vm_local_hostname
  }
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm_name}_cloudinit.iso"
  user_data      = file("${path.module}/user-data.yaml")
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
    network_name = libvirt_network.local-network.name
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
    libvirt_network.local-network
  ]
}