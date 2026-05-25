output "ssh_config_path" {
  description = "Absolute path to the generated ssh-config file."
  value       = local_file.ssh_config.filename
}

output "vms" {
  description = "Per-VM ssh entries — useful for inspection."
  value = [
    for vm in local.vms : {
      name       = vm.name
      primary_ip = vm.primary_ip
      entries    = vm.entries
    }
  ]
}
