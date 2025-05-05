output "network" {
  value = data.external.net_info.result.network
}

output "prefix" {
  value = data.external.net_info.result.prefix
}

output "netmask" {
  value = data.external.net_info.result.netmask
}

output "gateway" {
  value = data.external.net_info.result.gateway
}
output "profile" {
  value = {
    kvm_network_name = var.kvm_network_name
    dhcp_mode        = "static"
    mask             = data.external.net_info.result.netmask
    gateway4         = data.external.net_info.result.gateway
    nameservers      = [data.external.net_info.result.gateway]
    bridge           = contains(keys(data.external.net_info.result), "bridge") ? data.external.net_info.result.bridge : null
  }
}

