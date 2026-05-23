output "groups" {
  description = "Groups map with var.vms appended under var.group_name (existing members preserved)."
  value = merge(
    var.groups,
    {
      (var.group_name) = concat(
        lookup(var.groups, var.group_name, []),
        var.vms,
      )
    }
  )
}