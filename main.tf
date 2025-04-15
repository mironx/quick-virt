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

resource "libvirt_volume" "ubuntu-vm-disk" {
  name   = "${var.vm_name}.qcow2"
  pool   = "default"
  source = "/var/lib/libvirt/images/ubuntu-2204.qcow2"
  format = "qcow2"
}

resource "libvirt_network" "terraform-net" {
  name      = "terraform-net"
  mode      = "nat"
  domain    = "local"
  addresses = ["192.168.100.0/24"]
  autostart = true
}

# resource "libvirt_volume" "ubuntu-vm-disk" {
#   name   = "vm_ubuntu22.qcow2"
#   pool   = "default"
#   source = "/var/lib/libvirt/images/vm_ubuntu22.qcow2"
#   format = "qcow2"

#   depends_on = [null_resource.create_linked_disk]
# }

# resource "libvirt_volume" "ubuntu-disk" {  
#   name   = "ubuntu-2204-vm.qcow2"
#   pool   = "default"
#   format = "qcow2"
#   size   = 5368709120 # 5 GiB
# }

resource "libvirt_cloudinit_disk" "cloudinit" {
  name           = "${var.vm_name}_cloudinit.iso"
  user_data      = file("${path.module}/user-data.yaml")
  meta_data      = file("${path.module}/meta-data.yaml")
}


resource "libvirt_domain" "ubuntu-vm" {
  name   = var.vm_name
  memory = 2048
  vcpu   = 2

  disk {    
    volume_id = libvirt_volume.ubuntu-vm-disk.id
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit.id

  network_interface {
    network_name = libvirt_network.terraform-net.name
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
    libvirt_volume.ubuntu-vm-disk,
    libvirt_cloudinit_disk.cloudinit,
    libvirt_network.terraform-net
  ]
}