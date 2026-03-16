output "volume" {
  value = {
    path    = libvirt_volume.base.path
    name    = libvirt_volume.base.name
    pool    = var.storage_pool
    os_name = coalesce(var.os_name, "custom")
    os_profile = {
      image            = local.selected_os.image
      network_template = local.selected_os.network_template
      interface_naming = local.selected_os.interface_naming
      interface_offset = local.selected_os.interface_offset
    }
  }
  description = "Base volume info to pass to quick-vm as os_volume"
}