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

module "vm1" {
  source = "../modules/vm_ubuntu_24"
  vm = {
    name = "vm_test_1"
    image_source = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
    vcpu         = 2
    memory       = 2048
    user_name    = "devx"
    network_desc_order = false
  }
  local_network_configuration = {
    is_enabled = true
    ip         = "192.168.100.15"
    mask       = "24"
    gateway4   = ""
    nameservers = []
    dhcp_mode  = "ips_static_other_dhcp"
  }
  bridge_network_configuration = {
    is_enabled = false
    ip         = "172.16.0.15"
    mask       = "12"
    gateway4   = ""
    nameservers = []
    dhcp_mode  = "ips_static_other_dhcp"
  }
}

module "vm2" {
  source = "../modules/vm_ubuntu_24"
  vm = {
    name = "vm_test_2"
    image_source = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
    vcpu         = 2
    memory       = 2048
    user_name    = "devx"
    network_desc_order = false
  }
  local_network_configuration = {
    is_enabled = true
    ip         = "192.168.100.16"
    mask       = "24"
    gateway4 = "192.168.100.1"
    nameservers = ["192.168.100.1"]
    # gateway4   = ""
    # nameservers = []
    dhcp_mode  = "static"
  }
  bridge_network_configuration = {
    is_enabled = false
    ip         = "172.16.0.16"
    mask       = "12"
    gateway4 = "172.16.0.1"
    nameservers = ["172.16.0.1"]
    # gateway4   = ""
    # nameservers = []
    dhcp_mode  = "static"
  }
}

module "vm3" {
  source = "../modules/vm_ubuntu_24"
  vm = {
    name = "vm_test_3"
    image_source = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
    vcpu         = 2
    memory       = 2048
    user_name    = "devx"
    network_desc_order = false
  }
  local_network_configuration = {
    is_enabled = true
    ip         = ""
    mask       = ""
    gateway4 = ""
    nameservers = []
    # gateway4   = ""
    # nameservers = []
    dhcp_mode  = "dhcp"
  }
  bridge_network_configuration = {
    is_enabled = false
    ip         = ""
    mask       = ""
    gateway4   = ""
    nameservers = []
    dhcp_mode  = "dhcp"
  }
}
