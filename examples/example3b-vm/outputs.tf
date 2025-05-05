output "vm1_name" {
  value       = module.vm1.vm_name
  description = "Name of VM1"
}

output "vm1_id" {
  value       = module.vm1.vm_id
  description = "ID of VM1"
}

output "vm1_ips" {
  value       = module.vm1.vm_ips
  description = "IP addresses of VM1"
}
