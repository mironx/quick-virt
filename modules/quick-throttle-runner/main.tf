terraform {
  required_version = ">= 1.3"
}

# ============================================================================
# Generates two bash scripts that consume throttle.ini (from
# quick-throttle-apply) plus per-axis profile files (from quick-throttle).
#
# Scripts are STATIC — no per-VM specialisation. Format version is baked
# in at terraform-time so they validate the .ini they read.
#
# Format version coordination: bump in ALL of
#   quick-throttle/templates/{cpu,disk,network}.ini.tmpl
#   quick-throttle-apply/templates/throttle.ini.tmpl
#   quick-throttle-runner/main.tf (local.format_version below)
# when making a breaking change.
# ============================================================================

locals {
  format_version = 1
}

resource "local_file" "apply_sh" {
  filename        = "${var.output_dir}/.qv-limits/qv-throttle.apply.sh"
  file_permission = "0755"

  content = templatefile("${path.module}/templates/apply.sh.tmpl", {
    format_version = local.format_version
  })
}

resource "local_file" "clear_sh" {
  filename        = "${var.output_dir}/.qv-limits/qv-throttle.clear.sh"
  file_permission = "0755"

  content = templatefile("${path.module}/templates/clear.sh.tmpl", {
    format_version = local.format_version
  })
}
