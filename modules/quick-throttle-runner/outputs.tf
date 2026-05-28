output "apply_script" {
  description = "Path to the generated apply script."
  value       = local_file.apply_sh.filename
}

output "clear_script" {
  description = "Path to the generated clear script."
  value       = local_file.clear_sh.filename
}

output "format_version" {
  description = "Format version this runner expects in throttle.ini and per-axis profile files."
  value       = local.format_version
}
