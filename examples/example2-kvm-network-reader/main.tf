locals {
  kvm_networks = [
    "qvexample-net-bridge",
    "qvexample-neta-loc-1",
    "qvexample-neta-loc-2",
  ]
}

module "net_info" {
  for_each         = toset(local.kvm_networks)
  source           = "../../modules/quick-kvm-network-reader"
  kvm_network_name = each.value
}

output "kvm_networks_info" {
  value = {
    for net, mod in module.net_info :
    net => {
       all_for_debug = mod.all_for_debug
    }
  }
}


output "kvm_networks_profile" {
  value = {
    for net, mod in module.net_info :
    net => {
      profile = mod.profile
    }
  }
}