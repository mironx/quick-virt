networks = {
  local0 = {
    kvm_network_name = "lab-net-0"
    mode             = "nat"
    domain           = "lab0.internal"
    mask             = "24"
    gateway4         = "10.10.10.1"
    nameservers      = ["10.10.10.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  local1 = {
    kvm_network_name = "lab-net-1"
    mode             = "nat"
    domain           = "lab1.internal"
    mask             = "24"
    gateway4         = "10.10.11.1"
    nameservers      = ["10.10.11.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  local2 = {
    kvm_network_name = "lab-net-2"
    mode             = "nat"
    domain           = "lab2.internal"
    mask             = "24"
    gateway4         = "10.10.12.1"
    nameservers      = ["10.10.12.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  local3 = {
    kvm_network_name = "lab-net-3"
    mode             = "nat"
    domain           = "lab3.internal"
    mask             = "24"
    gateway4         = "10.10.13.1"
    nameservers      = ["10.10.13.1"]
    dhcp_mode        = "static"
    autostart        = true },
  # ----------------------------------------------------------------
  # Update configuration bridge section according to your environment.
  # Example: bridge = "br0"
  # Make sure to create the bridge interface on your Linux system and connect it
  # to a physical network interface.
  # You can use the helper scripts located in the scripts/linux-bridge directory.
  #
  bridge = {
    kvm_network_name = "bridge-net"
    mode             = "bridge"
    mask             = "12"
    gateway4         = "172.20.0.1"
    nameservers      = ["172.20.0.1"]
    dhcp_mode        = "static"
    bridge           = "br0"
    autostart        = true
  }
  # ----------------------------------------------------------------
}
