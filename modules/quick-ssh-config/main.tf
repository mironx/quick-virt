locals {
  set_name      = var.set_name
  identity_file = var.identity_file != null ? var.identity_file : "~/.ssh/id_rsa"
  nodes         = var.nodes
  file_name     = var.file_name != null ? var.file_name : "${path.root}/quick-ssh-config-${local.set_name}"
}

resource "local_file" "ssh_config" {
  filename = local.file_name

  content = join("\n", compact(flatten([
    "#--------------------------------------------------- ${local.set_name}",

    [
      for node in local.nodes : [
        for idx, net in node.networks :
        net.ip != null && net.ip != "" ? trimspace(<<-EOT
Host ${local.set_name}-${node.name}${idx == 0 ? "" : "-${net.profile_name}"}
  HostName ${net.ip}
  User devx
  IdentityFile ${local.identity_file}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOT
        ) : null
      ]
    ],

    "#--------------------------------------------------- ${local.set_name}"
  ])))
}