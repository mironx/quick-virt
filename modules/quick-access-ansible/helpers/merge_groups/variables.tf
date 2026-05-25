variable "group_maps" {
  description = <<-EOT
    List of groups maps to merge. Each map is `{ group_name => list(vm_info) }`,
    typically `module.<quick-vms>.vms_info_by_set`.

    When the same group_name appears in multiple input maps, the VM lists are
    concatenated end-to-end (NOT replaced like Terraform's built-in merge()).
    Dedup by VM name happens downstream in the consuming quick-access-* module.

    Example:
      group_maps = [
        module.vms1.vms_info_by_set,    # { masters = [a, b], workers = [c, d] }
        module.vms2.vms_info_by_set,    # { masters = [e, f], cache    = [g, h] }
      ]
      # → { masters = [a, b, e, f], workers = [c, d], cache = [g, h] }
  EOT
  type    = any
  default = []
}
