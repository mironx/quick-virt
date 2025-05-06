local-kvm-network-name = "neta-loc-2"
bridge-kvm-network-name = "net-bridge"
machines = {
  masters = {
    set_name = "black-master"
    vm_profile = {
      vcpu   = 1
      memory = 2048
    },
    main_storage = {
      size = 30
    },
    user = {
      name     = "ubuntu"
      password = "ubuntu123"
    }
    cloud_unit_user_data = "./templates/master-user-data.tmpl"
    nodes = [
      {
        name        = "v1"
        local_ip    = "192.168.101.3"
        bridge_ip   = "172.20.0.17"
        description = "black virtual machine"
      },
      {
        name        = "v2"
        local_ip    = "192.168.101.4"
        bridge_ip   = "172.20.0.18"
        description = "black virtual machine"
      },
      {
        name        = "v3"
        local_ip    = "192.168.101.5"
        bridge_ip   = "172.20.0.19"
        description = "black virtual machine"
      }
    ]
  },
  workers = {
    set_name = "black-worker"
    vm_profile = {
      vcpu   = 3
      memory = 4048
    },
    main_storage = {
      size = 40
    },
    user = {
      name     = "ubuntu"
      password = "ubuntu123"
    }
    cloud_unit_user_data = "./templates/worker-user-data.tmpl"
    nodes = [
      {
        name        = "v1"
        local_ip    = "192.168.101.33"
        bridge_ip   = "172.20.0.37"
        description = "black virtual machine"
      },
      {
        name        = "v2"
        local_ip    = "192.168.101.34"
        bridge_ip   = "172.20.0.38"
        description = "black virtual machine"
      },
      {
        name        = "v3"
        local_ip    = "192.168.101.35"
        bridge_ip   = "172.20.0.39"
        description = "black virtual machine"
      },
      {
        name        = "v4"
        local_ip    = "192.168.101.36"
        bridge_ip   = "172.20.0.40"
        description = "black virtual machine"
      }
    ]
  }
}