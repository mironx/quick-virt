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

locals {
  prefix = "qvms-ex5"

  kvm_networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = false }
  }

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = "ubuntu"
    user_password = "ubuntu123"
  })
}

# Shared base volume — one image, used by both vms_A and vms_B
module "base_os" {
  source      = "../../modules/quick-os-volume"
  volume_name = "${local.prefix}-os-volume"
  os_name     = "ubuntu_22"
}

module "vms_A" {
  source = "../../modules/quick-vms"

  kvm-networks = local.kvm_networks

  machines = {
    servers = {
      set_name  = "${local.prefix}-A-server"
      os_volume = module.base_os.volume
      vm_profile = {
        vcpu   = 1
        memory = 2048
      }
      user = {
        name     = "ubuntu"
        password = "ubuntu123"
      }
      cloud_init_user_data_path = "./templates/user-data.tmpl"
      nodes = [
        {
          name = "v1"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.60" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.60" }
          ]
        },
        {
          name = "v2"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.61" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.61" }
          ]
        }
      ]
    }
  }
}

module "vms_B" {
  source = "../../modules/quick-vms"

  kvm-networks = local.kvm_networks

  machines = {
    workers = {
      set_name  = "${local.prefix}-B-worker"
      os_volume = module.base_os.volume
      vm_profile = {
        vcpu   = 2
        memory = 4096
      }
      user = {
        name     = "ubuntu"
        password = "ubuntu123"
      }
      cloud_init_user_data_path = "./templates/user-data.tmpl"
      nodes = [
        {
          name = "v1"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.70" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.70" }
          ]
        },
        {
          name = "v2"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.71" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.71" }
          ]
        }
      ]
    }
  }
}

# vms_C — clone mode with os_name (each VM gets its own full copy)
module "vms_C" {
  source = "../../modules/quick-vms"

  kvm-networks = local.kvm_networks

  machines = {
    cloned = {
      set_name  = "${local.prefix}-C-cloned"
      os_name   = "ubuntu_22"
      os_disk_mode = "clone"
      vm_profile = {
        vcpu   = 1
        memory = 2048
      }
      user = {
        name     = "ubuntu"
        password = "ubuntu123"
      }
      cloud_init_user_data_path = "./templates/user-data.tmpl"
      nodes = [
        {
          name = "v1"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.80" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.80" }
          ]
        },
        {
          name = "v2"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.81" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.81" }
          ]
        }
      ]
    }
  }
}

# vms_D — clone mode with os_profile (custom image, each VM gets its own full copy)
module "vms_D" {
  source = "../../modules/quick-vms"

  kvm-networks = local.kvm_networks

  machines = {
    custom = {
      set_name = "${local.prefix}-D-custom"
      os_profile = {
        image            = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
        network_template = "netplan"
        interface_naming = "enp0s"
      }
      os_disk_mode = "clone"
      vm_profile = {
        vcpu   = 1
        memory = 2048
      }
      user = {
        name     = "ubuntu"
        password = "ubuntu123"
      }
      cloud_init_user_data_path = "./templates/user-data.tmpl"
      nodes = [
        {
          name = "v1"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.90" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.90" }
          ]
        },
        {
          name = "v2"
          networks = [
            { profile_name = "qvexample-neta-loc-2", ip = "192.168.201.91" },
            { profile_name = "qvexample-net-bridge", ip = "172.20.0.91" }
          ]
        }
      ]
    }
  }
}

output "vms_A" {
  value = module.vms_A.vms_info
}

output "vms_B" {
  value = module.vms_B.vms_info
}

output "vms_C" {
  value = module.vms_C.vms_info
}

output "vms_D" {
  value = module.vms_D.vms_info
}

output "kvm_network_profiles" {
  value = module.vms_A.kvm-network-profiles
}