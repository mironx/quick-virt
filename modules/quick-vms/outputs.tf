output "vms_info" {
  description = "Combined info (name, id, static IPs) for all virtual machines"
  value = {
    for vm_key, vm in module.vms : vm_key => {
      name        = vm.vm_name
      id          = vm.vm_id
      static_ips  = vm.vm_ips
    }
  }
}
