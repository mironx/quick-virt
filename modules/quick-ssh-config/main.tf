locals {
  set_name      = var.set_name
  identity_file = var.identity_file != null ? var.identity_file : "~/.ssh/id_rsa"
  nodes         = var.nodes
  file_name     = var.file_name != null ? var.file_name : "${path.root}/ssh-config-${local.set_name}"
}

resource "local_file" "ssh_config" {
  filename = local.file_name

  content = join("\n", compact(flatten([
    "#--------------------------------------------------- ${local.set_name}",

    [
      for node in local.nodes : (
        (node.local_ip != null && node.local_ip != "") || (node.bridge_ip != null && node.bridge_ip != "") ?
        join("\n", compact([
          node.local_ip != null && node.local_ip != "" ? trimspace(<<-EOT
Host ${local.set_name}-${node.name}
  HostName ${node.local_ip}
  User devx
  IdentityFile ${local.identity_file}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOT
          ) : null,

          node.bridge_ip != null && node.bridge_ip != "" ? trimspace(<<-EOT
Host ${local.set_name}-${node.name}-viabridge
  HostName ${node.bridge_ip}
  User devx
  IdentityFile ${local.identity_file}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOT
          ) : null
        ])) : null
      )
    ],

    "#--------------------------------------------------- ${local.set_name}"
  ])))
}