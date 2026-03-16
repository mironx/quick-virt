output "vms" {
  value = {
    for name, mod in {
      A = module.vm_A
      B = module.vm_B
      C = module.vm_C
      # D1 = module.vm_D1  # clone not supported
      # D2 = module.vm_D2  # clone not supported
      E = module.vm_E
    } : name => {
      name       = mod.vm_name
      networks   = mod.vm_networks
      os_profile = mod.vm_os_profile
      vm_profile = mod.vm_profile
    }
  }
}
