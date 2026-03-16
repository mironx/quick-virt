# Project Structure

## Directory Layout

```
quick-virt/
├── Taskfile.yml                  # Task runner configuration
├── modules/                      # Terraform modules
│   ├── quick-vm/                 # Single VM provisioning
│   ├── quick-vms/                # Multi-VM provisioning
│   ├── quick-networks/           # KVM network creation
│   ├── quick-kvm-network-reader/ # Read KVM network info
│   ├── quick-kvm-storage-pool-reader/ # Read KVM storage pool info
│   ├── quick-ssh-config/         # SSH config generation
│   └── quick-hosts/              # Hosts file generation
├── examples/                     # Usage examples
│   ├── example1-network/         # Create KVM networks
│   ├── example2-kvm-network-reader/ # Read and display network parameters
│   ├── example3a-vm/             # Single VM (profile via reader)
│   ├── example3b-vm/             # Single VM (with profile_name)
│   └── example4-vms/             # Multi-VM cluster setup
├── scripts/                      # Helper shell scripts
│   ├── setup/                    # System setup scripts
│   ├── linux-bridge/             # Bridge management scripts
│   └── tools/                    # Utility and cleanup tools
└── doc/                          # Documentation
```

## Modules

### quick-vm

Provisions a single KVM virtual machine with flexible network configuration.

- Supports **local** and **bridge** network interfaces
- Each interface can use **DHCP** or **static IP**
- Network profile can be provided via `profile` (object) or `profile_name` (string — triggers internal reader)
- Cloud-init integration: user-data, meta-data, network-config (v2 format)
- Validation: preconditions check network profile correctness and report errors with VM name and network details

### quick-vms

Provisions multiple VMs from a declarative configuration map. Wraps `quick-vm` and adds:

- Shared network profile reader (one reader per network, shared across all VMs)
- SSH config generation via `quick-ssh-config`
- Hosts file generation via `quick-hosts`
- Cloud-init user-data from template file or inline template

### quick-networks

Creates KVM virtual networks (NAT or bridge mode) from a configuration map.

### quick-kvm-network-reader

Reads KVM network configuration using `virsh net-dumpxml` and exposes it as a Terraform-compatible profile. Outputs include network address, mask, gateway, mode, and an `error` field for graceful error handling (e.g., bridge interface without IPv4).

Includes a test script: `scripts/kvm-net-info-test.sh`

### quick-ssh-config

Generates SSH config file entries for a set of VMs (local and bridge IPs).

### quick-hosts

Generates `/etc/hosts`-style entries for a set of VMs.

### quick-kvm-storage-pool-reader

Reads KVM storage pool information.

## Scripts

### Setup (`scripts/setup/`)

| Script | Description |
|--------|-------------|
| `install-kvm.sh` | Installs KVM, libvirt, QEMU, and related virtualization packages. Enables and starts the libvirtd service. |

### Linux Bridge (`scripts/linux-bridge/`)

| Script | Description |
|--------|-------------|
| `create-bridge.sh` | Creates a Linux network bridge using NetworkManager (`nmcli`). Attaches a physical interface as a slave, clones its MAC address, and configures DHCP. Usage: `--phys-if <iface> --bridge-name <name>` |
| `restore-network.sh` | Removes the bridge and restores original network configuration. |
| `show-bridge-status.sh` | Displays comprehensive bridge status: link state, IPv4/IPv6 addresses, slave interfaces, STP, NetworkManager state, libvirt network mapping, and attached VMs. Provides actionable recommendations for detected issues. Usage: `[bridge_name]` (all bridges if omitted) |

### Tools (`scripts/tools/`)

| Script | Description |
|--------|-------------|
| `clean-all-vms.sh` | Force-removes all VMs (destroy + undefine). Use when Terraform state is broken or inconsistent. |
| `clean-kvm-network.sh` | Force-removes all KVM-defined networks. |
| `get-os-image.sh` | Download, list, and remove OS cloud images (ubuntu_22, ubuntu_24, rocky_9, debian_12). |

## Network Flow

```
kvm-net-info.sh (virsh) → JSON {mode, network, mask, gateway, error, ...}
  → quick-kvm-network-reader/outputs.tf → profile {kvm_network_name, mask, gateway4, error, ...}
    → quick-vm (via profile or profile_name) → cloud-init network-config v2
      → libvirt_domain (network_interface blocks)
```

The `error` field in the profile enables graceful handling: if a network has issues (e.g., bridge without IPv4), VMs that require it will fail with a clear precondition message instead of cryptic errors.