data "external" "net_info" {
  program = ["${path.module}/scripts/kvm-net-info.sh"]

  query = {
    kvm_network_name = var.kvm_network_name
  }
}
