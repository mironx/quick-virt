output "inventory_path" {
  description = "Absolute path to the generated Ansible inventory file."
  value       = local_file.inventory.filename
}

output "vms" {
  description = "Deduped list of VMs with resolved primary_ip — useful for downstream wiring."
  value = [
    for vm in local.vms : {
      name       = vm.name
      primary_ip = vm.primary_ip
    }
  ]
}

output "groups" {
  description = "Group membership map (group_name => list of VM names) — for inspection/debug."
  value       = local.groups_by_vm_names
}