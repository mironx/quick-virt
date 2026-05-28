output "cpu_files" {
  description = "Map of CPU config name → generated .ini file path."
  value       = { for k, f in local_file.cpu : k => f.filename }
}

output "disk_files" {
  description = "Map of disk config name → generated .ini file path."
  value       = { for k, f in local_file.disk : k => f.filename }
}

output "network_files" {
  description = "Map of network config name → generated .ini file path."
  value       = { for k, f in local_file.network : k => f.filename }
}

output "cpu_names" {
  description = "Sorted list of CPU config names available."
  value       = sort(keys(var.cpu_configs))
}

output "disk_names" {
  description = "Sorted list of disk config names available."
  value       = sort(keys(var.disk_configs))
}

output "network_names" {
  description = "Sorted list of network config names available."
  value       = sort(keys(var.network_configs))
}

output "available_files" {
  description = "Bare filenames (no path) of generated .ini files per axis, ready to drop into throttle.ini as profile values. Pass to quick-throttle-apply.available_profiles for auto-discovery comment."
  value = {
    cpu     = sort([for k, f in local_file.cpu : basename(f.filename)])
    disk    = sort([for k, f in local_file.disk : basename(f.filename)])
    network = sort([for k, f in local_file.network : basename(f.filename)])
  }
}

output "prefix" {
  description = "The namespace prefix used in filenames (echoed for convenience)."
  value       = var.prefix
}
