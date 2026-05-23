output "vms_info" {
  description = "Combined info for all virtual machines (flat map keyed by '<set>-<node>')"
  value = {
    for vm_key, vm in module.vms : vm_key => {
      name           = vm.vm_name
      id             = vm.vm_id
      ips            = vm.vm_ips
      networks       = vm.vm_networks
      os_profile     = vm.vm_os_profile
      vm_profile     = vm.vm_profile
      shared_folders = vm.vm_shared_folders
    }
  }
}

output "vms_info_by_set" {
  description = "VMs grouped by set key — shape matches quick-access.groups input directly"
  value = {
    for set_key, set_val in var.machines : set_key => [
      for node in set_val.nodes : module.vms["${set_key}-${node.name}"].vm_info
    ]
  }
}