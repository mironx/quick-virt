terraform {
  required_version = ">= 1.3"
}

# ============================================================================
# Bootstrap-only mapping file. All fields start as 'null' (apply.sh
# downstream interprets null = unthrottle that axis).
# User edits throttle.ini manually for chaos sessions; terraform will only
# re-render the file when the set of vms / their disks / networks changes
# (content hash drift). Pure-edit sessions (no HCL change) are preserved.
# ============================================================================

locals {
  # Sort by VM name for deterministic file content (avoids spurious diffs
  # when caller passes vms in different order).
  _vms_by_name = { for vm in var.vms : vm.name => vm }

  vm_specs = [
    for name in sort(keys(local._vms_by_name)) : {
      name            = name
      disks           = try(local._vms_by_name[name].disks, ["vda"])
      network_indices = [for n in try(local._vms_by_name[name].networks, []) : n.index]
    }
  ]
}

resource "local_file" "mapping" {
  filename        = "${var.output_dir}/.qv-limits/${var.prefix}-throttle.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/throttle.ini.tmpl", {
    vms                = local.vm_specs
    generated_at       = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())
    prefix             = var.prefix
    available_profiles = var.available_profiles
  })
}
