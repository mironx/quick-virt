output "vm_name" {
  value       = libvirt_domain.vm.name
  description = "The name of the virtual machine"
}

output "vm_id" {
  value       = libvirt_domain.vm.id
  description = "The ID of the virtual machine resource"
}

output "vm_ips" {
  value       = try(libvirt_domain.vm.devices.interfaces[*].addresses, [])
  description = "List of IP addresses assigned to the virtual machine"
}

output "vm_networks" {
  value = [
    for idx, n in local.resolved_networks : {
      index            = idx
      interface        = "${local.selected_os.interface_naming}${idx + local.selected_os.interface_offset + (
        local.selected_os.interface_naming == "eth" ? 0 : length(var.shared_folders)
      )}"
      ip               = n.ip
      profile_name     = n.profile_name
      kvm_network_name = try(n.profile.kvm_network_name, n.profile_name)
    }
  ]
  description = "Resolved network configuration for the VM"
}

output "vm_os_profile" {
  value = {
    os_name          = coalesce(var.os_name, "ubuntu_22")
    image            = local.selected_os.image
    os_image_mode       = var.os_image_mode
    os_disk_mode        = var.os_disk_mode
    network_template = local.selected_os.network_template
    interface_naming = local.selected_os.interface_naming
  }
  description = "Resolved OS profile for the VM"
}

output "vm_profile" {
  value = {
    vcpu   = local.current_vm_profile.vcpu
    memory = local.current_vm_profile.memory
  }
  description = "VM compute profile"
}