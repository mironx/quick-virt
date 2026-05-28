output "mapping_file" {
  description = "Path to the generated throttle.ini mapping file."
  value       = local_file.mapping.filename
}

output "vm_names" {
  description = "Sorted list of VM names that appear in the mapping file."
  value       = sort([for vm in local.vm_specs : vm.name])
}
