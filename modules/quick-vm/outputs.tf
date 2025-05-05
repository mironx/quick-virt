output "vm_name" {
  value       = libvirt_domain.vm.name
  description = "The name of the virtual machine"
}

output "vm_id" {
  value       = libvirt_domain.vm.id
  description = "The ID of the virtual machine resource"
}

output "vm_ips" {
  value       = libvirt_domain.vm.network_interface[*].addresses
  description = "List of IP addresses assigned to the virtual machine"
}
