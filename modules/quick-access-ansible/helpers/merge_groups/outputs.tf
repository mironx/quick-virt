output "groups" {
  description = "Merged groups map. Lists at overlapping keys are concatenated, not replaced."
  value = {
    for k in distinct(flatten([for m in var.group_maps : keys(m)])) :
    k => concat([for m in var.group_maps : lookup(m, k, [])]...)
  }
}
