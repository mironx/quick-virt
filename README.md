# Quick-Virt

**Quick-Virt** is a collection of Terraform modules and shell scripts designed to simplify the process of creating and managing KVM-based virtual machines (VMs) on Linux for development purposes.  
The project was tested and run on **Ubuntu 24.04 LTS**.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## Key Features

- Rapid creation of KVM networks and VMs using Terraform.
- Modular structure to support single VM or multiple node cluster provisioning.
- SSH and hosts file generation for easy access and connectivity.
- Includes helper scripts for system setup and recovery.


## Core Module: `quick-vm`

The `quick-vm` module is the foundation of the project. It enables the creation of a **single VM** with flexible network configuration options:

- **Local interface** with **DHCP** or **static IP** support
- **Bridge interface** with **DHCP** or **static IP** support

To extract information about available KVM networks (e.g., name, type, address), the module `quick-kvm-network-reader` can be used.


## Multi-VM Setup: `quick-vms`

The `quick-vms` module allows the creation of a **subset of nodes** based on a given configuration file. It automates:

- Provisioning of multiple VMs
- SSH configuration generation (`quick-ssh-config`)
- Hosts file generation (`quick-hosts`)

Ensure your cloud-init configuration includes your **public SSH key** to enable passwordless access.


## Modules Overview

Each module is located in the [`modules`](./modules) directory:

| Module | Description |
|--------|-------------|
| [`quick-vm`](./modules/quick-vm) | Provision a single VM with support for user-data, meta-data, and network-config |
| [`quick-vms`](./modules/quick-vms) | Provision multiple VMs based on a configuration file |
| [`quick-networks`](./modules/quick-networks) | Create KVM virtual networks |
| [`quick-kvm-network-reader`](./modules/quick-kvm-network-reader) | Read and expose KVM network info via script |
| [`quick-kvm-storage-pool-reader`](./modules/quick-kvm-storage-pool-reader) | Read KVM storage pool info |
| [`quick-ssh-config`](./modules/quick-ssh-config) | Generate SSH config for easy access to VMs |
| [`quick-hosts`](./modules/quick-hosts) | Generate `hosts` entries for VMs |

Each module contains a `variables.tf` describing input parameters and a `main.tf` with logic. Outputs are defined in `outputs.tf` (if applicable).

## Examples

The [`examples`](./examples) directory demonstrates how to use the modules:

| Example | Description |
|---------|-------------|
| [`example1-network`](./examples/example1-network) | Create a KVM network |
| [`example2-kvm-network-reader`](./examples/example2-kvm-network-reader) | Read and display network parameters |
| [`example3a-vm`](./examples/example3a-vm) | Single VM creation with DHCP |
| [`example3b-vm`](./examples/example3b-vm) | Single VM with static IP |
| [`example4-vms`](./examples/example4-vms) | Multiple VMs, with SSH and hosts config |

## Scripts Overview

The `scripts` directory includes helper and recovery tools that assist with environment setup and management:

### Setup Scripts

Located in [`scripts/setup`](./scripts/setup):

| Script | Description |
|--------|-------------|
| [`01-install-kvm.sh`](./scripts/setup/01-install-kvm.sh) | Installs KVM, libvirt, and related packages required for virtualization |
| [`02-disaple-app-arrmor`](./scripts/setup/02-disaple-app-arrmor) | Disables AppArmor to avoid interference with libvirt (use with caution) |

---

### Linux Bridge Scripts

Located in [`scripts/linux-bridge`](./scripts/linux-bridge):

| Script | Description |
|--------|-------------|
| [`create-bridge.sh`](./scripts/linux-bridge/create-bridge.sh) | Creates a Linux network bridge to use with VMs in bridged mode |
| [`restore-network.sh`](./scripts/linux-bridge/restore-network.sh) | Restores original system networking by removing the bridge |

---

### Utility Tools

Located in [`scripts/tools`](./scripts/tools):

| Script | Description |
|--------|-------------|
| [`clean-all-vms.sh`](./scripts/tools/clean-all-vms.sh) | Removes all VMs manually (for broken or unrecoverable Terraform state) |
| [`clean-kvm-network.sh`](./scripts/tools/clean-kvm-network.sh) | Removes KVM-defined networks forcefully |
| [`get-iso-ubuntu22.sh`](./scripts/tools/get-iso-ubuntu22.sh) | Downloads Ubuntu 22.04 ISO for use with VMs |

These scripts are helpful during development and troubleshooting when Terraform state becomes inconsistent or broken.

## External Links
KVM: https://www.linux-kvm.org

Terraform Libvirt Provider: https://github.com/dmacvicar/terraform-provider-libvirt

Cloud-Init: https://cloudinit.readthedocs.io/en/latest/
