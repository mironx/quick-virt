locals {
  set_name      = var.set_name
  identity_file = var.identity_file != null ? var.identity_file : "~/.ssh/id_rsa"
  nodes         = var.nodes
  file_name     = var.file_name != null ? var.file_name : "${path.root}/qv-ssh-config-${local.set_name}.qv-info"

  host_entries = flatten([
    for node in local.nodes : [
      for idx, net in node.networks :
      net.ip != null && net.ip != "" ? {
        host = "${local.set_name}-${node.name}-net${idx}-${net.profile_name}"
        ip   = net.ip
      } : null
    ]
  ])

  valid_entries = [for e in local.host_entries : e if e != null]
}

resource "local_file" "ssh_config" {
  filename = local.file_name

  content = join("\n", compact(flatten([
    "#--------------------------------------------------- ${local.set_name}",
    "# Include in ~/.ssh/config:",
    "#   Include ${local.file_name}",
    "#",
    "# Or use directly:",
    [for e in local.valid_entries : "#   ssh -F ${local.file_name} ${e.host}"],
    "#--------------------------------------------------- ${local.set_name}",
    "",

    [
      for e in local.valid_entries : trimspace(<<-EOT
Host ${e.host}
  HostName ${e.ip}
  User ${var.user}
  IdentityFile ${local.identity_file}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOT
      )
    ],

    "#--------------------------------------------------- ${local.set_name}"
  ])))
}