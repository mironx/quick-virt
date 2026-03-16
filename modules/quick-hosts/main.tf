locals {
  set_name  = var.set_name
  nodes     = var.nodes
  file_name = var.file_name != null ? var.file_name : "${path.root}/qv-hosts-${local.set_name}.qv-info"
}

resource "local_file" "hosts_file" {
  filename = local.file_name

  content = join("\n", compact(flatten([
    "#----------------------------- ${local.set_name}",

    [
      for node in local.nodes : [
        for idx, net in node.networks :
        net.ip != null && net.ip != "" ?
          "${net.ip} ${local.set_name}-${node.name}-net${idx}-${net.profile_name}"
        : null
      ]
    ],

    "#----------------------------- ${local.set_name}"
  ])))
}