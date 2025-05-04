locals {
  set_name      = var.set_name
  identity_file = var.identity_file != null ? var.identity_file : "~/.ssh/id_rsa"
  nodes         = var.nodes
  file_name     = var.file_name != null ? var.file_name : "${path.root}/ssh_config_${local.set_name}"
}

resource "local_file" "ssh_config" {
  filename = local.file_name

  content = join("\n", compact(flatten([
    "#--------------------------------------------------- ${local.set_name}",

    [
      for vm in local.nodes : (
        (vm.local_ip != null && vm.local_ip != "") || (vm.bridge_ip != null && vm.bridge_ip != "") ?
        join("\n", compact([
          vm.local_ip != null && vm.local_ip != "" ? trimspace(<<-EOT
Host ${vm.name}
  HostName ${vm.local_ip}
  User devx
  IdentityFile ${local.identity_file}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOT
          ) : null,

          vm.bridge_ip != null && vm.bridge_ip != "" ? trimspace(<<-EOT
Host ${vm.name}-viabridge
  HostName ${vm.bridge_ip}
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