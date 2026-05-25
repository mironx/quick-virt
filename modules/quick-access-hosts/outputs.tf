output "hosts_path" {
  description = "Absolute path to the generated hosts file."
  value       = local_file.hosts.filename
}

output "vms" {
  description = "Per-VM host entries — useful for inspection."
  value = [
    for vm in local.vms : {
      name       = vm.name
      primary_ip = vm.primary_ip
      entries    = vm.entries
    }
  ]
}
