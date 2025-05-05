networks = {
  neta-loc-1 = {
    kvm_network_name = "neta-loc-1"
    mode             = "nat"
    domain           = "la1.local"
    mask             = "24"
    gateway4         = "192.168.100.1"
    nameservers      = ["192.168.100.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  neta-loc-2 = {
    kvm_network_name = "neta-loc-2"
    mode             = "nat"
    domain           = "la2.local"
    mask             = "24"
    gateway4         = "192.168.101.1"
    nameservers      = ["192.168.101.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  neta-loc-3 = {
    kvm_network_name = "neta-loc-3"
    mode             = "nat"
    domain           = "la3.local"
    mask             = "24"
    gateway4         = "192.168.102.1"
    nameservers      = ["192.168.102.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  neta-loc-4 = {
    kvm_network_name = "neta-loc-4"
    mode             = "nat"
    domain           = "la4.local"
    mask             = "24"
    gateway4         = "192.168.103.1"
    nameservers      = ["192.168.103.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
   netb-loc-1 = {
    kvm_network_name = "netb-loc-1"
    mode             = "nat"
    domain           = "lb1.internal"
    mask             = "24"
    gateway4         = "10.10.10.1"
    nameservers      = ["10.10.10.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  netb-loc-2 = {
    kvm_network_name = "netb-loc-2"
    mode             = "nat"
    domain           = "lb2.internal"
    mask             = "24"
    gateway4         = "10.10.11.1"
    nameservers      = ["10.10.11.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  netb-loc-3 = {
    kvm_network_name = "netb-loc-3"
    mode             = "nat"
    domain           = "lb3.internal"
    mask             = "24"
    gateway4         = "10.10.12.1"
    nameservers      = ["10.10.12.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  netb-loc-4 = {
    kvm_network_name = "netb-loc-4"
    mode             = "nat"
    domain           = "lb4.internal"
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
  net-bridge = {
    kvm_network_name = "net-bridge"
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
