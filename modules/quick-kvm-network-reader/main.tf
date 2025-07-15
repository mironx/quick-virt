terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }
}

data "external" "net_info" {
  program = ["${path.module}/scripts/kvm-net-info.sh"]

  query = {
    kvm_network_name = var.kvm_network_name
  }
}
