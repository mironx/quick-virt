locals {
  kvm_networks = [
    "net-bridge",
    "neta-loc-1",
    "neta-loc-2",
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
      network = mod.network
      gateway = mod.gateway
      prefix  = mod.prefix
      netmask = mod.netmask
    }
  }
}


output "kvm_networks_profile" {
  value = {
    for net, mod in module.net_info :
    net => {
      network = mod.profile
    }
  }
}