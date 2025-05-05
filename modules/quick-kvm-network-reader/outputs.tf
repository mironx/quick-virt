output "network" {
  value = data.external.net_info.result.network
}

output "mask_prefix" {
  value = data.external.net_info.result.mask_prefix
}

output "mask_ip" {
  value = data.external.net_info.result.mask_ip
}

output "gateway" {
  value = data.external.net_info.result.gateway
}

output "mode" {
  value = data.external.net_info.result.mode
}

output "profile" {
  value = {
    kvm_network_name = var.kvm_network_name
    dhcp_mode        = "static"
    mask             = data.external.net_info.result.mask_prefix
    gateway4         = data.external.net_info.result.gateway
    nameservers      = [data.external.net_info.result.gateway]
    bridge           = data.external.net_info.result.mode == "bridge" ? data.external.net_info.result.bridge : null
    mode             = data.external.net_info.result.mode
  }
}

output "all_for_debug" {
  value = {
    kvm_network_name = var.kvm_network_name
    dhcp_mode        = "static"
    mask_ip          = data.external.net_info.result.mask_ip
    mask_prefix      = data.external.net_info.result.mask_prefix
    gateway4         = data.external.net_info.result.gateway
    nameservers = [data.external.net_info.result.gateway]
    bridge           = data.external.net_info.result.mode == "bridge" ? data.external.net_info.result.bridge : null
    mode             = data.external.net_info.result.mode
    network          = data.external.net_info.result.network
  }
}
