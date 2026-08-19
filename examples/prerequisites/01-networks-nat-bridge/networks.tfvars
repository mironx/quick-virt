networks = {
  qvexample-neta-loc-1 = {
    kvm_network_name = "qvexample-neta-loc-1"
    mode             = "nat"
    domain           = "la1.local"
    mask             = "24"
    gateway4         = "192.168.200.1"
    nameservers      = ["192.168.200.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  qvexample-neta-loc-2 = {
    kvm_network_name = "qvexample-neta-loc-2"
    mode             = "nat"
    domain           = "la2.local"
    mask             = "24"
    gateway4         = "192.168.201.1"
    nameservers      = ["192.168.201.1"]
    dhcp_mode        = "static"
    autostart        = true
  },
  # ----------------------------------------------------------------
  # Update configuration bridge section according to your environment.
  # Example: bridge = "br0"
  # Make sure to create the bridge interface on your Linux system and connect it
  # to a physical network interface.
  # You can use the helper scripts located in the scripts/linux-bridge directory.
  #
  qvexample-net-bridge = {
    kvm_network_name = "qvexample-net-bridge"
    mode             = "bridge"
    mask             = "12"
    gateway4         = "172.16.0.1"
    nameservers      = ["172.16.0.1"]
    dhcp_mode        = "static"
    bridge           = "br0"
    autostart        = true
  }
  # ----------------------------------------------------------------
}
