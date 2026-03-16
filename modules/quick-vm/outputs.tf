output "vm_name" {
  value       = libvirt_domain.vm.name
  description = "The name of the virtual machine"
}

output "vm_id" {
  value       = libvirt_domain.vm.id
  description = "The ID of the virtual machine resource"
}

output "vm_ips" {
  value       = try(libvirt_domain.vm.devices.interfaces[*].addresses, [])
  description = "List of IP addresses assigned to the virtual machine"
}

output "vm_networks" {
  value = [
    for idx, n in local.resolved_networks : {
      index            = idx
      interface        = "enp0s${idx + 3}"
      ip               = n.ip
      profile_name     = n.profile_name
      kvm_network_name = try(n.profile.kvm_network_name, n.profile_name)
    }
  ]
  description = "Resolved network configuration for the VM"
}