locals {
  set_name  = var.set_name
  nodes     = var.nodes
  file_name = var.file_name != null ? var.file_name : "${path.root}/hosts-${local.set_name}"
}

resource "local_file" "hosts_file" {
  filename = local.file_name

  content = join("\n", compact(flatten([
    "#----------------------------- ${local.set_name}",

    [
      for node in local.nodes : (
        (node.local_ip != null && node.local_ip != "") || (node.bridge_ip != null && node.bridge_ip != "") ?
        compact([
          node.local_ip != null && node.local_ip != "" ? "${node.local_ip} ${local.set_name}-${node.name}" : null,
          node.bridge_ip != null && node.bridge_ip != "" ? "${node.bridge_ip} ${local.set_name}-${node.name}-viabridge" : null
        ]) : null
      )
    ],

    "#----------------------------- ${local.set_name}"
  ])))
}
