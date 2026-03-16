output "vms_info" {
  description = "Combined info for all virtual machines"
  value       = {
    for vm_key, vm in module.vms : vm_key => {
      name       = vm.vm_name
      id         = vm.vm_id
      ips        = vm.vm_ips
      networks   = vm.vm_networks
      os_profile = vm.vm_os_profile
      vm_profile = vm.vm_profile
    }
  }
}